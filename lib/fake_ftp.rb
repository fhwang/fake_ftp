require File.expand_path(
  File.dirname(__FILE__) + '/../vendor/dyn-ftp-serv/dynftp_server'
)
require 'rubygems'
require 'active_support'
require 'httparty'
require 'logger'
require 'rack'
require 'sinatra'

Thread.abort_on_exception = true

module FakeFTP  
  class BackDoorClient
    include HTTParty
    
    base_uri "http://127.0.0.1:9803"
    format   :json
  end
  
  class BackDoorServer < Sinatra::Base
    cattr_accessor :behaviors
    
    def self.reset_behaviors
      self.behaviors = {}
    end
    
    reset_behaviors
    
    def self.max_connections
      behaviors['*'] && behaviors['*']['maxconns'] &&
        behaviors['*']['maxconns'].to_i
    end
  
    set :server, 'mongrel'
    
    get '/' do
      ''
    end

    get '/behaviors' do
      self.behaviors.to_json
    end
    
    post '/behaviors' do
      if params[:behavior] && !params[:behavior].empty?
        self.behaviors = self.behaviors.merge params[:behavior]
      else
        self.behaviors = {}
      end
      self.behaviors.to_json
    end
  end

  class FileSystemProvider
    attr_reader :ftp_name, :ftp_size, :ftp_dir, :ftp_date
  
    def ftp_parent
      path = @path.split('/')
      return nil unless path.pop
      return nil if path.size <= 1
      return FileSystemProvider.new(path.join('/'))
    end
  
    def ftp_list
      output = Array.new
      Dir.entries(@path).sort.each do |file|          
        output << FileSystemProvider.new(@path + (@path == '/'? '': '/') + file)
      end
      return output
    end
    
    def ftp_create(name, dir = false)
      if dir
        begin
          Dir.mkdir(@path + '/' + name)
          return FileSystemProvider.new(@path + '/' + name)
        rescue
          return false
        end
      else
        FileSystemProvider.new(@path + '/' + name)
      end
      
    end
    
    def ftp_retrieve(output)
      output << File.new(@path, 'r').read
    end
    
    def ftp_store(input)
      return false unless File.open(@path, 'w') do |f|
        f.write input.read
      end
      @ftp_size = File.size?(@path)
      @ftp_date = File.mtime(@path) if File.exists?(@path)
    end
    
    def ftp_delete()
      FileUtils.rm @path
      true
    end
    
    def initialize(path)
      @path = path
      @ftp_name = path.split('/').last
      @ftp_name = '/' unless @ftp_name
      @ftp_dir = File.directory?(path)    
      @ftp_size = File.size?(path)
      @ftp_size = 0 unless @ftp_size
      @ftp_date = Time.now
      @ftp_date = File.mtime(path) if File.exists?(path)
    end
  end

  class Server < DynFTPServer
    def initialize(conf = {})
      @live_connections = 0
      @back_door_thread = Thread.new do
        Rack::Handler::Mongrel.run(
          Rack::ShowExceptions.new(BackDoorServer.new), :Port => 9803
        ) do |server|
          @back_door_server = server
        end
      end
      root = FileSystemProvider.new conf[:root_dir]
      auth =
        lambda do |user,pass|
          return false unless user.casecmp('anonymous') == 0
          return true
        end
      conf = {:port => 21, :root => root, :authentication => auth}.merge(conf)
      super(conf)
      @ftp_thread = Thread.new do
        mainloop
      end
    end
    
    def all_services_running?
      @ftp_thread.alive? && begin
        FakeFTP::BackDoorClient.get '/'
      rescue Errno::ECONNREFUSED
        false
      end
    end
    
    def any_services_running?
      @ftp_thread.alive? || begin
        FakeFTP::BackDoorClient.get '/'
      rescue Errno::ECONNREFUSED
        false
      end
    end
    
    def client_loop
      if BackDoorServer.max_connections.nil? or
         BackDoorServer.max_connections > @live_connections
        begin
          @live_connections += 1
          super
        ensure
          @live_connections -= 1
        end
      else
        status(
          421,
          "#{BackDoorServer.max_connections} users (the maximum) are already logged in, sorry"
        )
      end
    end
    
    def shutdown
      @back_door_server.stop
      @back_door_thread.kill
      @ftp_thread.kill
      @server.close
      BackDoorServer.reset_behaviors
    end
    
    DynFTPServer.private_instance_methods.select { |m| m=~/^cmd_/ }.each do |m|
      define_method(m) do |params|
        if BackDoorServer.behaviors['*'] == 'hang'
          while true; end
        else
          m =~ /^cmd_(.*)/
          if BackDoorServer.behaviors[$1] == 'hang'
            while true; end
          else
            super(params)
          end
        end
      end
    end
  end
end

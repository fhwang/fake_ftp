require File.expand_path(
  File.dirname(__FILE__) + '/../vendor/dyn-ftp-serv/dynftp_server'
)
require 'rubygems'
require 'active_support'
require 'logger'
require 'rack'  

Thread.abort_on_exception = true

module FakeFTP
  class BackDoor
    def call(env)
      res = Rack::Response.new
      res.write [].to_json
      res.finish
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
      return false
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
      @backdoor_thread = Thread.new do
        Rack::Handler::WEBrick.run(
          Rack::ShowExceptions.new(Rack::Lint.new(BackDoor.new)),
          :Port => 9803
        )
      end
      log  = Logger.new(STDOUT)
      log.datetime_format = "%H:%M:%S"
      log.progname = "ftpserv.rb"
      root = FileSystemProvider.new('/')
      auth =
        lambda do |user,pass|
          return false unless user.casecmp('anonymous') == 0
          return true
        end
      conf = {
        :port => 21, :root => root, :authentication => auth,
        :logger => log
      }.merge(conf)
      super conf
    end
  end
end

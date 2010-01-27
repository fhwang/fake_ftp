require File.expand_path(File.dirname(__FILE__) + '/../lib/fake_ftp_server')
require 'httparty'

module FakeFTP
  class BackDoorClient
    include HTTParty
    
    base_uri "http://127.0.0.1:9803"
    format   :json
  end
end

describe "FakeFTP when first booted" do
  before :each do
    @fake_ftp_server = FakeFTP::Server.new :port => 21212
    @server_thread = Thread.new do
      @fake_ftp_server.mainloop
    end
  end
  
  it 'should return an empty list of /behaviors' do
    until @server_thread
      sleep 0.1
    end
    sleep 5.0
    behaviors = FakeFTP::BackDoorClient.get '/behaviors'
    behaviors.should == []
  end
end

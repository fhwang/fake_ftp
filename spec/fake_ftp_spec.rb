require File.expand_path(File.dirname(__FILE__) + '/../lib/fake_ftp_server')
require 'net/ftp'

describe "FakeFTP when first booted" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.running?
  end
  
  it 'should return an empty list of /behaviors' do
    behaviors = FakeFTP::BackDoorClient.get '/behaviors'
    behaviors.should == []
  end
  
  it 'should see the README' do
    ftp = Net::FTP.new
    ftp.connect('127.0.0.1', 21212)
    ftp.login('anonymous', 'asdf')
    files = ftp.list('*')
    files.any? { |file| file =~ / README$/ }.should be_true
  end
end

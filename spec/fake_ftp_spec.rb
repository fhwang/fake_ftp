require File.expand_path(File.dirname(__FILE__) + '/../lib/fake_ftp')
require 'net/ftp'

module FakeFTPSpecHelper
  def assert_readme_visible
    ftp = Net::FTP.new
    ftp.connect('127.0.0.1', 21212)
    ftp.login('anonymous', 'asdf')
    files = ftp.list('*')
    files.any? { |file| file =~ / README$/ }.should be_true
  end
end

Spec::Runner.configure do |config|
  include FakeFTPSpecHelper
end

describe "FakeFTP when first booted" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.all_services_running?
  end
  
  after :all do
    @fake_ftp_server.shutdown
    sleep 0.1 while @fake_ftp_server.any_services_running?
  end
  
  it 'should return an empty list of /behaviors' do
    behaviors = FakeFTP::BackDoorClient.get '/behaviors'
    behaviors.should == {}
  end
  
  it 'should see the README' do
    assert_readme_visible
  end
end

describe "FakeFTP shutdown" do
  it 'should succeed' do
    fake1 = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until fake1.all_services_running?
    assert_readme_visible
    fake1.shutdown
    sleep 0.1 while fake1.any_services_running?
    fake2 = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until fake2.all_services_running?
    assert_readme_visible
    fake2.shutdown
    sleep 0.1 while fake2.any_services_running?
  end
end

describe "FakeFTP that's been programmed to hang" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.all_services_running?
    FakeFTP::BackDoorClient.post(
      '/behaviors', :query => {:behavior => {'*' => 'hang'}}
    )
  end
  
  after :all do
    @fake_ftp_server.shutdown
    sleep 0.1 while @fake_ftp_server.any_services_running?
  end
  
  it "should say it's ready to hang" do
    FakeFTP::BackDoorClient.get('/behaviors').should == {'*' => 'hang'}
  end
  
  it 'should actually hang' do
    lambda {
      Timeout.timeout(5) do
        assert_readme_visible
      end
    }.should raise_error(Timeout::Error)
  end
end

describe "FakeFTP that's been programmed to hang and is then reset" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.all_services_running?
    FakeFTP::BackDoorClient.post(
      '/behaviors', :query => {:behavior => {'*' => 'hang'}}
    )
    FakeFTP::BackDoorClient.post '/behaviors', :query => {:behaviors => {}}
  end
  
  after :all do
    @fake_ftp_server.shutdown
    sleep 0.1 while @fake_ftp_server.any_services_running?
  end
  
  it "should say it's ready to act normally" do
    FakeFTP::BackDoorClient.get('/behaviors').should == {}
  end
  
  it 'should see the README' do
    assert_readme_visible
  end
end

describe "FakeFTP that's been programmed to only hang on list" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.all_services_running?
    FakeFTP::BackDoorClient.post(
      '/behaviors', :query => {:behavior => {'list' => 'hang'}}
    )
  end
  
  after :all do
    @fake_ftp_server.shutdown
    sleep 0.1 while @fake_ftp_server.any_services_running?
  end
  
  it "should say it's ready to hang" do
    FakeFTP::BackDoorClient.get('/behaviors').should == {'list' => 'hang'}
  end
  
  it 'should connect and login fine' do
    ftp = Net::FTP.new
    ftp.connect('127.0.0.1', 21212)
    ftp.login('anonymous', 'asdf')
  end
  
  it 'should actually hang when you list' do
    lambda {
      Timeout.timeout(5) do
        assert_readme_visible
      end
    }.should raise_error(Timeout::Error)
  end
end

describe "FakeFTP with two connections" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.all_services_running?
  end
  
  after :all do
    @fake_ftp_server.shutdown
    sleep 0.1 while @fake_ftp_server.any_services_running?
  end

  it 'should handle both just fine' do
    thread1 = Thread.new { assert_readme_visible }
    thread2 = Thread.new { assert_readme_visible }
    [thread1, thread2].each do |t| t.join; end
  end
end

describe "FakeFTP that restricts to one connection" do
  before :all do
    @fake_ftp_server = FakeFTP::Server.new(
      :port => 21212, :root_dir => './spec/ftp_root/'
    )
    sleep 0.1 until @fake_ftp_server.all_services_running?
    FakeFTP::BackDoorClient.post(
      '/behaviors', :query => {:behavior => {'*' => {'maxconns' => 1}}}
    )
  end
  
  after :all do
    @fake_ftp_server.shutdown
    sleep 0.1 while @fake_ftp_server.any_services_running?
  end

  it 'should raise an error on the 2nd connection' do
    ftp1 = Net::FTP.new
    ftp1.connect('127.0.0.1', 21212)
    ftp2 = Net::FTP.new
    lambda {
      ftp2.connect('127.0.0.1', 21212)
    }.should raise_error(
      Net::FTPTempError,
      /421 1 users \(the maximum\) are already logged in, sorry/
    )
    ftp1.close
    ftp2.connect('127.0.0.1', 21212)
  end
end


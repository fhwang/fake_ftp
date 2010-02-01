require File.expand_path(File.dirname(__FILE__) + '/../lib/fake_ftp_server')
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
    behaviors.should == []
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
    assert_readme_visible
    fake2.shutdown
  end
end


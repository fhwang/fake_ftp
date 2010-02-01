#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/fake_ftp')

FakeFTP::Server.new :root_dir => '/'
while true; end

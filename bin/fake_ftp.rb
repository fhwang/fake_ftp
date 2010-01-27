#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/fake_ftp_server')

f = FakeFTP::Server.new :root_dir => '/'
f.mainloop


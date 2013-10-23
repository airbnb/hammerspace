#!/usr/bin/env ruby
$:.push File.expand_path('../../lib', __FILE__)
$:.push File.expand_path('../../spec', __FILE__)

require 'trollop'
require 'hammerspace'
require 'support/write_concurrency_test'
require 'fileutils'

include WriteConcurrencyTest

opts = Trollop::options do
  opt :path, 'Path to hammerspace root', :default => '/tmp'
  opt :backend, 'Hammerspace backend to use', :default => 'Sparkey'
  opt :concurrency, 'Number of writer processes to fork', :default => 10
  opt :iterations, 'Number of times each process should write', :default => 10
  opt :size, 'Number of items to write on each iteration', :default => 10
end

path = File.join(opts[:path], 'write_concurrency_test')

begin
  run_write_concurrency_test(
    path,
    {
      :backend => Hammerspace::Backend.const_get(opts[:backend])
    },
    opts[:concurrency],
    opts[:iterations],
    opts[:size])
ensure
  FileUtils.rm_rf(path)
end

puts "OK"


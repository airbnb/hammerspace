#!/usr/bin/env ruby
$:.push File.expand_path('../../lib', __FILE__)
$:.push File.expand_path('../../spec', __FILE__)

require 'trollop'
require 'benchmark'
require 'hammerspace'
require 'fileutils'

opts = Trollop::options do
  opt :path, 'Path to hammerspace root', :default => '/tmp'
  opt :backend, 'Hammerspace backend to use', :default => 'Sparkey'
  opt :iterations, 'Number of read/write cycles', :default => 10
  opt :keys, 'Number of items in the hammerspace', :default => 10_000
  opt :length, 'Length of each item in the hammerspace', :default => 100
  opt :update_factor, 'Percentage of items to update on each iteration', :default => 0.1
  opt :read_factor, 'Percentage of items to read on each iteration', :default => 0.1
end

path = File.join(opts[:path], 'benchmark')
options = { :backend => Hammerspace::Backend.const_get(opts[:backend]) }

begin
  Benchmark.bm do |benchmark|
    benchmark.report('write') do
      opts[:iterations].times do
        hash = Hammerspace.new(path, options)
        opts[:keys].times { |i| hash[i.to_s] = 'x' * opts[:length] }
        hash.close
        hash.clear
      end
    end

    hash = Hammerspace.new(path, options)
    opts[:keys].times { |i| hash[i.to_s] = 'x' * opts[:length] }
    hash.close

    benchmark.report('update') do
      opts[:iterations].times do
        hash = Hammerspace.new(path, options)
        (opts[:keys] * opts[:update_factor]).to_i.times do
          hash[rand(opts[:keys]).to_s] = 'y' * opts[:length]
        end
        hash.close
      end
    end

    benchmark.report('read') do
      opts[:iterations].times do
        hash = Hammerspace.new(path, options)
        (opts[:keys] * opts[:read_factor]).to_i.times do
          raise unless hash[rand(opts[:keys]).to_s]
        end
        hash.close
      end
    end
  end
ensure
  FileUtils.rm_rf(path)
end


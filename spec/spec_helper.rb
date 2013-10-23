require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

SimpleCov.use_merging false

# from https://gist.github.com/clicube/5017378
pid = Process.pid
SimpleCov.at_exit do
  SimpleCov.result.format! if Process.pid == pid
end

require 'hammerspace'

require 'support/sparkey_directory_helper'
require 'support/write_concurrency_test'

RSpec.configure do |config|
  config.color_enabled = true
  config.include(WriteConcurrencyTest)
end

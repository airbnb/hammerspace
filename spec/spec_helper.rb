require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

require 'hammerspace'

RSpec.configure do |config|
  config.color_enabled = true
end

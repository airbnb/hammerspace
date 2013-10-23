require 'colored'

require 'hammerspace/version'
require 'hammerspace/backend'
require 'hammerspace/hash'

module Hammerspace

  def self.new(path, options={}, &block)
    Hash.new(path, options, &block)
  end

end

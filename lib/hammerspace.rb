require 'colored'

require 'hammerspace/version'
require 'hammerspace/backend'
require 'hammerspace/hash'

module Hammerspace

  def self.new(path, options={}, *args, &block)
    Hash.new(path, options, *args, &block)
  end

end

require 'hammerspace/version'
require 'hammerspace/backend'
require 'hammerspace/hash'

module Hammerspace

  def self.new(path, options={})
    if block_given?
      Hash.new(path, options) { |*args| yield(*args) }
    else
      Hash.new(path, options)
    end
  end

end

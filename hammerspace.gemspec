# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require 'hammerspace/version'

Gem::Specification.new do |s|
  s.name         = "hammerspace"
  s.version      = Hammerspace::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Jon Tai", "Nelson Gauthier"]
  s.email        = ["jon.tai@airbnb.com", "nelson@airbnb.com"]
  s.homepage     = "https://github.com/airbnb/hammerspace"
  s.summary      = "Hash-like interface to persistent, concurrent, off-heap storage"
  s.description  = "A convenient place to store giant hammers"

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'

  s.add_runtime_dependency 'sparkey', '1.3.0'
end

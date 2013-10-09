# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require 'hammerspace/version'

Gem::Specification.new do |s|
  s.name         = "hammerspace"
  s.version      = Hammerspace::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Jon Tai"]
  s.email        = ["jon.tai@airbnb.com"]
  s.homepage     = "https://github.com/airbnb/hammerspace"
  s.summary      = "Off-heap large object storage"
  s.description  = "Where one stores oversized objects, like giant hammers"

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'

  s.add_runtime_dependency 'gnista', '0.0.4'
end

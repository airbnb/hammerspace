# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require 'hammerspace/version'

Gem::Specification.new do |s|
  s.name         = "hammerspace"
  s.version      = Hammerspace::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = `git log --format=%an -- lib`.split($/).uniq
  s.email        = `git log --format=%ae -- lib`.split($/).uniq.grep(/airbnb.com$/)
  s.homepage     = "https://github.com/airbnb/hammerspace"
  s.summary      = "Hash-like interface to persistent, concurrent, off-heap storage"
  s.description  = "A convenient place to store giant hammers"

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'

  s.add_runtime_dependency 'gnista', '0.0.5'
end

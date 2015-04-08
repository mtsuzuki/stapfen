# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stapfen/version'

Gem::Specification.new do |s|
  s.name          = "stapfen"
  s.version       = [Stapfen::VERSION, ENV['TRAVIS_BUILD_NUMBER'] || 'dev'].join('.')
  s.authors       = ["R. Tyler Croy"]
  s.email         = ["rtyler.croy@lookout.com"]
  s.description   = "A simple gem for writing good basic workers"
  s.summary       = "A simple gem for writing good basic workers"
  s.homepage      = "https://github.com/lookout/stapfen"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency 'thread_safe'

  if RUBY_PLATFORM == "java"
    s.add_dependency 'hermann', "~> 0.22.0"
    s.platform = 'java'
  end
end

# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stapfen/version'

Gem::Specification.new do |s|
  s.name          = "stapfen"
  s.version       = Stapfen::VERSION
  s.authors       = ["R. Tyler Croy"]
  s.email         = ["rtyler.croy@lookout.com"]
  s.description   = "A simple gem for writing good basic STOMP workers"
  s.summary       = "A simple gem for writing good basic STOMP workers"
  s.homepage      = ""

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  if RUBY_PLATFORM == "java"
    s.add_dependency 'hermann', "~> 0.20.0"
    s.platform = 'java'
  end
end

# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "business/version"

Gem::Specification.new do |spec|
  spec.name          = "business"
  spec.version       = Business::VERSION
  spec.authors       = ["Harry Marr"]
  spec.email         = ["developers@gocardless.com"]
  spec.summary       = "Date calculations based on business calendars"
  spec.description   = "Date calculations based on business calendars"
  spec.homepage      = "https://github.com/gocardless/business"
  spec.licenses      = ["MIT"]

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.require_paths = ["lib"]

  spec.add_development_dependency "gc_ruboconfig", "~> 3.6.0"
  spec.add_development_dependency "rspec", "~> 3.1"
  spec.add_development_dependency "rubocop", "~> 1.47.0"
  spec.metadata["rubygems_mfa_required"] = "true"
end

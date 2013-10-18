# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bank_time/version'

Gem::Specification.new do |spec|
  spec.name          = "bank_time"
  spec.version       = BankTime::VERSION
  spec.authors       = ["Harry Marr"]
  spec.email         = ["engineering@gocardless.com"]
  spec.description   = %q{Date calculations based on bank calendars}
  spec.summary       = %q{Date calculations based on bank calendars}
  spec.homepage      = "https://github.com/gocardless/bank_time"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec", "~> 2.14.1"
end

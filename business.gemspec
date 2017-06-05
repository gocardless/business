lib = File.expand_path("../lib", __FILE__)
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
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec", "~> 3.1"
  spec.add_development_dependency "rubocop", "~> 0.49.1"
end

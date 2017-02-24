# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'debouncer/version'

Gem::Specification.new do |spec|
  spec.name          = 'debouncer'
  spec.version       = Debouncer::VERSION
  spec.authors       = ['Neil E. Pearson']
  spec.email         = ['neil@pearson.sydney']

  spec.summary       = 'Debouncer'
  spec.description   = 'Background thread debouncing for Ruby.'
  spec.homepage      = 'https://github.com/hx/debouncer'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end

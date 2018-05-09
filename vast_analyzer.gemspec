# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vast_analyzer/version'

Gem::Specification.new do |spec|
  spec.name = 'vast_analyzer'
  spec.version = VastAnalyzer::VERSION
  spec.authors = ['Marina Chirchikova']

  spec.summary = 'A VAST analyzer that autodetects VPAID, flash, and js in VAST media files'
  spec.homepage = 'https://github.com/marina101/vast-analyzer'
  spec.license = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.3.0'
  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_runtime_dependency 'nokogiri', '>= 1.8.1'
  spec.add_development_dependency 'rubocop', '0.39.0'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'minitest-vcr'
  spec.add_development_dependency 'byebug'
  spec.add_runtime_dependency 'addressable'
end

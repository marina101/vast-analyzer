# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'vast_analyzer'
require 'minitest/autorun'
require 'vcr'
require 'minitest-vcr'
require 'webmock/minitest'

VCR.configure do |c|
  c.cassette_library_dir = 'test/cassettes'
  c.hook_into :webmock
end

MinitestVcr::Spec.configure!

# frozen_string_literal: true
require 'test_helper'
require 'vcr'
require 'vast_analyzer'
require 'byebug'
require 'webmock/minitest'

class ParserTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::VastAnalyzer::VERSION
  end

  def test_parser_raises_error_when_not_given_url
    error = assert_raises VastAnalyzer::ErrorOpeningUrl do
      VCR.use_cassette('not_uri') do
        VastAnalyzer::Parser.new('cherrycoke')
      end
    end
    assert_match 'Error opening url', error.message
  end

  def test_parser_raises_not_vast_error_when_uri_given_is_not_vast
    error = assert_raises VastAnalyzer::NotVastError do
      VCR.use_cassette('google') do
        VastAnalyzer::Parser.new('https://www.google.com')
      end
    end
    assert_match 'Error: not vast', error.message
  end

  def test_custom_max_depth_value_doesnt_raise_error_on_correct_input
    VCR.use_cassette('custom_initialize') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?'\
        'line_item=13796381&subid1=vpaidjsonly', :max_redirects => 3)
      assert_equal 'js_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_categorize_identifies_js_and_flash_vpaid
    VCR.use_cassette('flash_js_vpaid_xml') do
      parser = VastAnalyzer::Parser.new('https://fw.adsafeprotected.com/vast/fwjsvid/st/58622/'\
        '9328507/skeleton.js?originalVast=https://bs.serving-sys.com/BurstingPipe/'\
        'adServer.bs?cn=is&c=23&pl=VAST&pli=18103306&PluID=0&pos=598&ord=%time%&cim=1')
      assert_equal 'flash_js_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_no_js_and_flash_vpaid_false_positives
    VCR.use_cassette('only_js') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13796381&subid1=vpaidjsonly')
      refute_equal 'flash_js_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_categorize_identifies_js_only_vpaid
    VCR.use_cassette('only_js') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13796381&subid1=vpaidjsonly')
      assert_equal 'js_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_has_no_js_only_false_positives
    VCR.use_cassette('flash_js_vpaid_xml') do
      parser = VastAnalyzer::Parser.new('https://fw.adsafeprotected.com/vast/fwjsvid/st/58622/'\
      '9328507/skeleton.js?originalVast=https://bs.serving-sys.com/BurstingPipe/adServer.bs?cn'\
      '=is&c=23&pl=VAST&pli=18103306&PluID=0&pos=598&ord=%time%&cim=1')
      refute_equal 'js_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_categorize_identifies_flash_only_vpaid
    VCR.use_cassette('only_flash_vpaid') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      assert_equal 'flash_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_has_no_flash_only_false_positives
    VCR.use_cassette('vast_without_vpaid') do
      parser = VastAnalyzer::Parser.new('https://d.adgear.com/impressions/ext_nc/p=223348.xml')
      refute_equal 'flash_vpaid', parser.attributes[:vpaid_status]
    end
  end

  def test_categorize_identifies_when_no_vpaid
    VCR.use_cassette('vast_without_vpaid') do
      parser = VastAnalyzer::Parser.new('https://d.adgear.com/impressions/ext_nc/p=223348.xml')
      assert_equal 'neither', parser.attributes[:vpaid_status]
    end
  end

  def test_no_vpaid_has_no_false_positives
    VCR.use_cassette('only_flash_vpaid') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      refute_equal 'neither', parser.attributes[:vpaid_status]
    end
  end

  def test_wrapper_successfully_unwrapped_and_redirected_to_ad
    VCR.use_cassette('simple_wrapper') do
      parser = VastAnalyzer::Parser.new('http://demo.tremorvideo.com/proddev/vast/vast_wrapper_linear_1.xml')
      assert !parser.vast.xpath('//mediafile').empty?
    end
  end

  def test_wrapper_depth_error_thrown_after_five_unwrapping_redirects
    error = assert_raises VastAnalyzer::WrapperDepthError do
      VCR.use_cassette('infinite_wrapper', :allow_playback_repeats => true) do
        VastAnalyzer::Parser.new('http://demo.tremorvideo.com/proddev/vast/vast_wrapper_linear_2.xml')
      end
    end
    assert_match 'Error: Wrapper depth exceeds five redirects', error.message
  end

  def test_error_raised_when_bad_wrapper_url
    error = assert_raises VastAnalyzer::WrapperRedirectError do
      VCR.use_cassette('bad_wrapper_url', :allow_playback_repeats => true) do
        VastAnalyzer::Parser.new('http://demo.tremorvideo.com/proddev/vast/vast_wrapper_linear_2.xml')
      end
    end
    assert_match 'Error with opening the wrapper url', error.message
  end

  def test_exception_raised_when_timeout_exceeded
    stub_request(:get, 'https://vast.brandads.net/vast?line_item=13796381&subid1=vpaidjsonly').to_timeout

    assert_raises VastAnalyzer::UrlTimeoutError do
      VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13796381&subid1=vpaidjsonly')
    end
  end

  def test_determine_vast_version_correctly_parses_version
    VCR.use_cassette('only_flash_vpaid') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      assert_match '2.0', parser.vast_version
    end
  end

  def test_exception_thrown_when_vast_version_not_determinable_or_deprecated
    assert_raises VastAnalyzer::NotVastError do
      VCR.use_cassette('bad_vast_version') do
        VastAnalyzer::Parser.new('http://demo.tremorvideo.com/proddev/vast/vast1VPAIDLinear.xml')
      end
    end
  end

  def test_skippable_detects_vast_3_skippable_ad
    VCR.use_cassette('vast_3_skippable') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      assert parser.attributes[:skippable] == true
    end
  end

  def test_skippable_detects_vast_3_not_skippable_ad
    VCR.use_cassette('vast_3_not_skippable') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      assert parser.attributes[:skippable] == false
    end
  end

  def test_skippable_detects_vast_2_skippable_ad
    VCR.use_cassette('vast_2_skippable') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      assert parser.attributes[:skippable] == true
    end
  end

  def test_skippable_detects_vast_2_non_skippable_ad
    VCR.use_cassette('only_flash_vpaid') do
      parser = VastAnalyzer::Parser.new('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      assert parser.attributes[:skippable] == false
    end
  end
end

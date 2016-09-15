# frozen_string_literal: true
require 'test_helper'
require 'vcr'
require 'vpaid_parser'
require 'byebug'

class ParserTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::VpaidParser::VERSION
  end

  def test_parser_raises_error_when_not_given_url
    error = assert_raises VpaidParser::ErrorOpeningUrl do
      VCR.use_cassette('not_uri') do
        uri = URI.parse('cherrycoke')
        VpaidParser::Parser.new(uri)
      end
    end
    assert_match 'Error opening url', error.message
  end

  def test_parser_raises_not_vast_error_when_uri_given_is_not_vast
    error = assert_raises VpaidParser::NotVastError do
      VCR.use_cassette('google') do
        uri = URI.parse('https://www.google.com')
        VpaidParser::Parser.new(uri)
      end
    end
    assert_match 'Error: not vast', error.message
  end

  def test_categorize_identifies_js_and_flash_vpaid
    VCR.use_cassette('flash_js_vpaid_xml') do
      uri = URI.parse('https://fw.adsafeprotected.com/vast/fwjsvid/st/58622/'\
        '9328507/skeleton.js?originalVast=https://bs.serving-sys.com/BurstingPipe/'\
        'adServer.bs?cn=is&c=23&pl=VAST&pli=18103306&PluID=0&pos=598&ord=%time%&cim=1')
      parser = VpaidParser::Parser.new(uri)
      assert_equal 'flash_js_vpaid', parser.categorize
    end
  end

  def test_no_js_and_flash_vpaid_false_positives
    VCR.use_cassette('only_js') do
      uri = URI.parse('https://vast.brandads.net/vast?line_item=13796381&subid1=vpaidjsonly')
      parser = VpaidParser::Parser.new(uri)
      refute_equal 'flash_js_vpaid', parser.categorize
    end
  end

  def test_categorize_identifies_js_only_vpaid
    VCR.use_cassette('only_js') do
      uri = URI.parse('https://vast.brandads.net/vast?line_item=13796381&subid1=vpaidjsonly')
      parser = VpaidParser::Parser.new(uri)
      assert_equal 'js_vpaid', parser.categorize
    end
  end

  def test_has_no_js_only_false_positives
    VCR.use_cassette('flash_js_vpaid_xml') do
      uri = URI.parse('https://fw.adsafeprotected.com/vast/fwjsvid/st/58622/9328507/'\
        'skeleton.js?originalVast=https://bs.serving-sys.com/BurstingPipe/adServer.bs?cn'\
        '=is&c=23&pl=VAST&pli=18103306&PluID=0&pos=598&ord=%time%&cim=1')
      parser = VpaidParser::Parser.new(uri)
      refute_equal 'js_vpaid', parser.categorize
    end
  end

  def test_categorize_identifies_flash_only_vpaid
    VCR.use_cassette('only_flash_vpaid') do
      uri = URI.parse('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      parser = VpaidParser::Parser.new(uri)
      assert_equal 'flash_vpaid', parser.categorize
    end
  end

  def test_has_no_flash_only_false_positives
    VCR.use_cassette('vast_without_vpaid') do
      uri = URI.parse('https://d.adgear.com/impressions/ext_nc/p=223348.xml')
      parser = VpaidParser::Parser.new(uri)
      refute_equal 'flash_vpaid', parser.categorize
    end
  end

  def test_categorize_identifies_when_no_vpaid
    VCR.use_cassette('vast_without_vpaid') do
      uri = URI.parse('https://d.adgear.com/impressions/ext_nc/p=223348.xml')
      parser = VpaidParser::Parser.new(uri)
      assert_equal 'neither', parser.categorize
    end
  end

  def test_no_vpaid_has_no_false_positives
    VCR.use_cassette('only_flash_vpaid') do
      uri = URI.parse('https://vast.brandads.net/vast?line_item=13822255&ba_cb=__RANDOM_NUMBER__')
      parser = VpaidParser::Parser.new(uri)
      refute_equal 'neither', parser.categorize
    end
  end

  def test_wrapper_successfully_unwrapped_and_redirected_to_ad
    VCR.use_cassette('simple_wrapper') do
      uri = URI.parse('http://demo.tremorvideo.com/proddev/vast/vast_wrapper_linear_1.xml')
      parser = VpaidParser::Parser.new(uri)
      assert !parser.vast.xpath('//mediafile').empty?
    end
  end

  def test_wrapper_depth_error_thrown_after_five_unwrapping_redirects
    error = assert_raises VpaidParser::WrapperDepthError do
      VCR.use_cassette('infinite_wrapper', :allow_playback_repeats => true) do
        uri = URI.parse('http://demo.tremorvideo.com/proddev/vast/vast_wrapper_linear_2.xml')
        VpaidParser::Parser.new(uri)
      end
    end
    assert_match 'Error: Wrapper depth exceeds five redirects', error.message
  end

  def test_error_raised_when_bad_wrapper_url
    error = assert_raises VpaidParser::WrapperRedirectError do
      VCR.use_cassette('bad_wrapper_url', :allow_playback_repeats => true) do
        uri = URI.parse('http://demo.tremorvideo.com/proddev/vast/vast_wrapper_linear_2.xml')
        VpaidParser::Parser.new(uri)
      end
    end
    assert_match 'Error with opening the wrapper url', error.message
  end
end

# frozen_string_literal: true
require 'vast_analyzer/version'
require 'vast_analyzer/errors'
require 'nokogiri'
require 'net/http'
require 'addressable/uri'

module VastAnalyzer

  def self.parse(url, max_redirects: 5)
    ParserResult.new(url)
  end

  class ParserResult
    attr_reader :vast, :vast_version

    def initialize(url, max_redirects: 5)
      open_xml(url)
      vast_root = @vast&.xpath('//VAST')
      raise NotVastError.new("Not vast, url: #{url}") unless vast_root&.any?
      unwrap(max_redirects) unless @vast.xpath('//VASTAdTagURI').empty?
      @vast_version = vast_root.attr('version').value
    end

    def vpaid_status
      if include_flash_vpaid? && include_js?
        'flash_js_vpaid'
      elsif include_flash_vpaid?
        'flash_vpaid'
      elsif include_js?
        'js_vpaid'
      else
        'neither'
      end
    end

    def skippable?
      @skippable ||=
        case @vast_version
        when '2.0', '2.0.1'
          !!@vast.xpath('//Tracking')&.any? { |track| track.attr('event') == 'skip' }
        when '3.0'
          !!@vast.xpath('//Linear').attr('skipoffset')
        end
    end

    def mediafiles
      @mediafiles ||= @vast.xpath('//MediaFile')&.map do |node|
        h = node.to_h
        h['url'] = node.content
        h
      end
    end

    private

    def open_xml(url, limit: 2)
      raise ArgumentError.new('Too many HTTP redirects') if limit == 0
      uri = Addressable::URI.parse(url)
      response = Net::HTTP.get_response(uri)
      case response
      when Net::HTTPSuccess
        @vast = Nokogiri::XML(response.body, nil, nil, Nokogiri::XML::ParseOptions.new.noblanks)
      when Net::HTTPRedirection
        open_xml(response['location'], :limit => limit - 1)
      else
        raise ErrorOpeningUrl.new("Net/http error, #{response.code}, #{response.message}"\
          "url: #{url}")
      end
    rescue Timeout::Error
      raise UrlTimeoutError.new('Timeout error')
    rescue StandardError => e
      raise ErrorOpeningUrl.new("Error opening url, #{e.message}")
    end

    def unwrap(max_redirects)
      max_redirects.times do
        return if @vast.xpath('//VASTAdTagURI').empty?
        begin
          url = @vast.xpath('//VASTAdTagURI')[0].content
          open_xml(url)
        rescue
          raise WrapperRedirectError.new('Error with opening the wrapper url')
        end
      end
      raise WrapperDepthError.new('Error: Wrapper depth exceeds five redirects')
    end

    def include_flash_vpaid?
      @include_flash ||= mediafiles.any? do |mediafile|
        is_vpaid_api = mediafile['apiFramework'] == 'VPAID'
        uses_flash = ['application/x-shockwave-flash', 'video/x-flv']
                     .include?(mediafile['type'])
        is_vpaid_api && uses_flash
      end
    end

    def include_js?
      @include_js ||= mediafiles.any? do |mediafile|
        ['application/x-javascript', 'application/javascript'].include?(mediafile['type'])
      end
    end
  end
  private_constant :ParserResult
end

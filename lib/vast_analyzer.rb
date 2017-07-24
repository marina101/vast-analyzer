# frozen_string_literal: true
require 'vast_analyzer/version'
require 'nokogiri'
require 'net/http'
require 'addressable/uri'
require 'vast_analyzer/errors'

module VastAnalyzer
  class Parser
    attr_reader :vast, :vast_version

    def initialize(url, max_redirects: 5)
      @attributes = {}
      open_xml(url)
      raise NotVastError.new("Not vast, url: #{url}") unless @vast&.xpath('//VAST')&.any?
      unwrap(max_redirects) unless @vast.xpath('//VASTAdTagURI').empty?
      @vast_version = @vast.xpath('//VAST').attr('version').value
    end

    def attributes
      {
        :vpaid_status => categorize,
        :skippable => skippable?
      }
    end

    private

    def categorize
      @mediafiles = @vast.xpath('//MediaFile')
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
      if @vast_version == '2.0' || @vast_version == '2.0.1'
        return false unless @vast.xpath('//Tracking')
        @vast.xpath('//Tracking').any? do |track|
          track.attr('event') == 'skip'
        end
      elsif @vast_version == '3.0'
        !!@vast.xpath('//Linear').attr('skipoffset')
      end
    end

    def open_xml(url, limit: 2)
      raise ArgumentError.new('Too many HTTP redirects') if limit == 0
      uri = Addressable::URI.parse(url)
      response = Net::HTTP.get_response(uri)
      case response
      when Net::HTTPSuccess
        @vast = Nokogiri::XML(response.body)
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
      @include_flash ||= @mediafiles.any? do |mediafile|
        is_vpaid_api = mediafile.attr('apiFramework') == 'VPAID'
        uses_flash = ['application/x-shockwave-flash', 'video/x-flv']
                     .include?(mediafile.attr('type'))
        is_vpaid_api && uses_flash
      end
    end

    def include_js?
      @include_js ||= @mediafiles.any? do |mediafile|
        ['application/x-javascript', 'application/javascript'].include?(mediafile.attr('type'))
      end
    end
  end
end

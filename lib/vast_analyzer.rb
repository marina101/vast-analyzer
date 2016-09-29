# frozen_string_literal: true
require 'vast_analyzer/version'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'vast_analyzer/errors'

module VastAnalyzer
  class Parser
    attr_reader :vast, :attributes, :vast_version

    def initialize(url, max_redirects: 5)
      @attributes = {}
      open_xml(url)
      raise NotVastError.new('Error: not vast') if @vast.xpath('//vast').empty?
      unwrap(max_redirects) unless @vast.xpath('//vastadtaguri').empty?
      @vast_version = @vast.xpath('//vast').attr('version').value
    end

    def categorize
      @mediafiles = @vast.xpath('//mediafile')
      if include_flash_vpaid? && include_js?
        @attributes.merge!(:vpaid_status => 'flash_js_vpaid')
      elsif include_flash_vpaid?
        @attributes.merge!(:vpaid_status => 'flash_vpaid')
      elsif include_js?
        @attributes.merge!(:vpaid_status => 'js_vpaid')
      else
        @attributes.merge!(:vpaid_status => 'neither')
      end
    end

    def skippable?
      if @vast_version == '2.0' || @vast_version == '2.0.1'
        return @attributes.merge!(:skippable => false) unless @vast.xpath('//tracking')
        skippable = @vast.xpath('//tracking').any? do |track|
          track.attr('event') == 'skip'
        end
        @attributes.merge!(:skippable => skippable)
      elsif @vast_version == '3.0'
        skippable = !!@vast.xpath('//linear').attr('skipoffset')
        @attributes.merge!(:skippable => skippable)
      end
    end

    private

    def open_xml(url, limit: 2)
      raise ArgumentError, 'Too many HTTP redirects' if limit == 0
      response = Net::HTTP.get_response(URI(url))
      case response
      when Net::HTTPSuccess
        @vast = Nokogiri::HTML(response.body)
      when Net::HTTPRedirection
        open_xml(response['location'], :limit => limit - 1)
      end
    rescue Timeout::Error
      raise UrlTimeoutError.new('Timeout error')
    rescue StandardError => e
      raise ErrorOpeningUrl.new("Error opening url, #{e.message}")
    end

    def unwrap(max_redirects)
      max_redirects.times do
        return if @vast.xpath('//vastadtaguri').empty?
        begin
          url = @vast.xpath('//vastadtaguri')[0].content
          open_xml(url)
        rescue
          raise WrapperRedirectError.new('Error with opening the wrapper url')
        end
      end
      raise WrapperDepthError.new('Error: Wrapper depth exceeds five redirects')
    end

    def include_flash_vpaid?
      @include_flash ||= @mediafiles.any? do |mediafile|
        is_vpaid_api = mediafile.attr('apiframework') == 'VPAID'
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

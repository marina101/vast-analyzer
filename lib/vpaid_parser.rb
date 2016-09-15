# frozen_string_literal: true
require 'vpaid_parser/version'
require 'nokogiri'
require 'open-uri'
require 'vpaid_parser/errors'

module VpaidParser
  class Parser
    attr_accessor :vast

    def initialize(url, max_redirects = 5)
      begin
        @vast = Nokogiri::HTML(open(url))
      rescue
        raise ArgumentError.new('Invalid url')
      end
      @max_depth = max_redirects
      unwrap unless @vast.xpath('//vastadtaguri').empty?
      @mediafiles = @vast.xpath('//mediafile')
      raise NotVastError.new('Error: not vast') if @vast.xpath('//vast').empty?
    end

    def categorize
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

    private

    def unwrap
      @max_depth.times do
        return if @vast.xpath('//vastadtaguri').empty?
        begin
          url = @vast.xpath('//vastadtaguri')[0].content
          @vast = Nokogiri::HTML(open(url))
        rescue
          raise ArgumentError.new('Invalid wrapper redirect url')
        end
      end
      raise WrapperDepthError.new('Error: Wrapper depth exceeds five redirects')
    end

    def include_flash_vpaid?
      @mediafiles.any? do |mediafile|
        is_vpaid_api = mediafile.attr('apiframework') == 'VPAID'
        uses_flash = ['application/x-shockwave-flash', 'video/x-flv']
                     .include?(mediafile.attr('type'))
        is_vpaid_api && uses_flash
      end
    end

    def include_js?
      @mediafiles.any? do |mediafile|
        ['application/x-javascript', 'application/javascript'].include?(mediafile.attr('type'))
      end
    end
  end
end

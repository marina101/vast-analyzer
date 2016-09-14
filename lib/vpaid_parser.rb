# frozen_string_literal: true
require 'vpaid_parser/version'
require 'nokogiri'
require 'open-uri'

module VpaidParser
  class Parser
    def initialize(url)
      @vast = Nokogiri::HTML(open(url))
      unwrap unless @vast.xpath('//vastadtaguri').empty?
      @mediafiles = @vast.xpath('//mediafile')
    rescue
      raise ArgumentError, 'Invalid url'
    end

    def categorize
      # note: need to throw exception if its not a vast at all
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
      begin
        5.times do
          url = @vast.xpath('//vastadtaguri')[0].content
          @vast = Nokogiri::HTML(open(url))
          break if @vast.xpath('//vastadtaguri').empty?
        end
      rescue
        raise ArgumentError, 'Invalid wrapper redirect url'
      end
      raise WrapperDepthError, 'Wrapper depth exceeds five redirects'
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

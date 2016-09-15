# frozen_string_literal: true
require 'vpaid_parser/version'
require 'nokogiri'
require 'open-uri'
require 'vpaid_parser/not_vast_error'
require 'vpaid_parser/wrapper_depth_error'


module VpaidParser
  class Parser
    def initialize(url)
      begin
        @vast = Nokogiri::HTML(open(url))
        unwrap unless @vast.xpath('//vastadtaguri').empty?
        @mediafiles = @vast.xpath('//mediafile')
      rescue
        raise ArgumentError, 'Invalid url'
      end
      raise NotVastError.new("Error: not vast") if @vast.xpath('//vast').empty?
    end

    def categorize
      # note: need to throw exception if its not a vast at all
      #raise  @vast.xpath('//vast')
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
      raise WrapperDepthError.new, 'Wrapper depth exceeds five redirects'
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

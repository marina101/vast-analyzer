# frozen_string_literal: true
require 'vast_analyzer/version'
require 'nokogiri'
require 'open-uri'
require 'vast_analyzer/errors'

module VastAnalyzer
  class Parser
    attr_accessor :vast

    def initialize(url, max_redirects = 5, timeout = 5)
      @timeout = timeout
      @max_depth = max_redirects
      open_xml(url)
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

    def open_xml(url)
      begin
        @vast = Nokogiri::HTML(open(url, :open_timeout => @timeout))
      rescue Timeout::Error => e
        raise UrlTimeoutError.new("Timeout error, #{e.message}")
      rescue OpenURI::HTTPError => e
        raise ErrorWithHttp.new("ErrorOpeningUrl, status: #{e.message}")
      rescue StandardError => e
        raise ErrorOpeningUrl.new("Error opening url, #{e.message}")
      end
    end

    def unwrap
      @max_depth.times do
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

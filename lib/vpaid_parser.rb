require 'vpaid_parser/version'
require 'nokogiri'
require 'open-uri'

class VpaidParser

  def initialize(url)
    begin
      @vast = Nokogiri::HTML(open(url))
      unwrap unless @vast.xpath("//vastadtaguri").empty?
	    @mediafiles = @vast.xpath('//mediafile')
    rescue
      raise ArgumentError, "Invalid url"
    end
  end

  def categorize
  	if include_flash_vpaid? && include_js?
  	  'flash_js'
  	elsif include_flash_vpaid? 
  	  'flash'
  	elsif include_js?
  	  'js'
  	else
  	  'neither'
  	end 
  end

  private
  
  def unwrap
  	begin
      5.times do 
        url = @vast.xpath("//vastadtaguri")[0].content
        @vast = Nokogiri::HTML(open(url))
        break if @vast.xpath("//vastadtaguri").empty?
      end
    rescue
      raise ArgumentError, "Invalid wrapper redirect url"
    end
    raise WrapperDepthError, "Wrapper depth exceeds five redirects"
  end
  	
  def include_flash_vpaid?
  	flash_vpaid = false
    @mediafiles.each do |mediafile|
	  if ((mediafile.attr('apiframework') == 'VPAID') && (mediafile.attr('type') == 'application/x-shockwave-flash' || mediafile.attr('type') == 'video/x-flv'))
	  	flash_vpaid = true
	  end
	end
	flash_vpaid
  end

  def include_js?
  	js = false
  	@mediafiles.each do |mediafile|
	  js = true if ((mediafile.attr('type') == 'application/x-javascript') || (mediafile.attr('type') == 'application/javascript'))
	end
	js
  end
end


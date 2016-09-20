# frozen_string_literal: true
module VastAnalyzer
  class Error < StandardError; end
  class ErrorOpeningUrl < Error; end
  class WrapperRedirectError < Error; end
  class NotVastError < Error; end
  class WrapperDepthError < Error; end
end

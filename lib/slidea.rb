# frozen_string_literal: true

require "time"

require_relative "slidea/cli"
require_relative "slidea/config"
require_relative "slidea/deck"
require_relative "slidea/llm_client"
require_relative "slidea/markdown_renderer"
require_relative "slidea/version"

module Slidea
  class Error < StandardError; end
  # Your code goes here...
end

# frozen_string_literal: true

require "time"

require_relative "slidict/auth_client"
require_relative "slidict/cli"
require_relative "slidict/config"
require_relative "slidict/credentials"
require_relative "slidict/deck"
require_relative "slidict/llm_client"
require_relative "slidict/markdown_renderer"
require_relative "slidict/version"

module Slidict
  class Error < StandardError; end
  # Your code goes here...
end

# frozen_string_literal: true

require "time"

require_relative "slidict/cli/options"
require_relative "slidict/cli/app"
require_relative "slidict/cli/lint"
require_relative "slidict/cli/serve"
require_relative "slidict/cli/slides"
require_relative "slidict/config"
require_relative "slidict/deck"
require_relative "slidict/env"
require_relative "slidict/external/slidict_io/auth"
require_relative "slidict/external/slidict_io/client"
require_relative "slidict/external/slidict_io/credentials"
require_relative "slidict/lint/finding"
require_relative "slidict/lint/linter"
require_relative "slidict/lint/renderer"
require_relative "slidict/lint/slide_parser"
require_relative "slidict/llm/client"
require_relative "slidict/output/format"
require_relative "slidict/output/renderer"
require_relative "slidict/presentation_method"
require_relative "slidict/version"

module Slidict
  class Error < StandardError; end
  # Your code goes here...
end

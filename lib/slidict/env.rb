# frozen_string_literal: true

module Slidict
  # Loads KEY=VALUE pairs from a .env file (if present) into ENV, so
  # SLIDICT_LLM_BASE_URL, SLIDICT_FRAMEWORK, etc. can be set once per project
  # instead of on every invocation. Only keys not already present in ENV are
  # populated -- a real environment variable always wins over .env, and a CLI
  # flag (read afterwards, in Cli::App#parse) wins over both. See `slidict
  # init` for generating a starter file.
  module Env
    LINE = /\A(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/

    def self.load!(path = ".env", env = ENV)
      return unless File.exist?(path)

      File.foreach(path) do |line|
        key, value = parse_line(line)
        env[key] = value if key && !env.key?(key)
      end
    end

    def self.parse_line(line)
      line = line.strip
      return [nil, nil] if line.empty? || line.start_with?("#")

      match = LINE.match(line)
      return [nil, nil] unless match

      [match[1], unquote(match[2].strip)]
    end
    private_class_method :parse_line

    # A quoted value keeps everything up to its closing quote verbatim (so a
    # "#" inside it isn't mistaken for a comment); an unquoted value has any
    # trailing "# comment" stripped.
    def self.unquote(value)
      if value.start_with?('"', "'")
        quote = value[0]
        closing = value.index(quote, 1)
        return closing ? value[1...closing] : value[1..]
      end

      value.sub(/\s+#.*\z/, "")
    end
    private_class_method :unquote
  end
end

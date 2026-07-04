# frozen_string_literal: true

module Slidict
  module Cli
    # Implements `slidict lint <file>`: diagnoses whether a Markdown/Asciidoc
    # slide deck has a structure that an audience can actually follow (not
    # whether it looks nice). Diagnosis only -- it does not rewrite the file.
    class Lint
      ASCIIDOC_EXTENSIONS = %w[.adoc .asciidoc].freeze

      include Options

      options output: Options::MISSING,
              linter_factory: -> { method(:default_linter) },
              renderer: -> { Slidict::Lint::Renderer.new }

      flag "--format",       arg: "FORMAT", desc: "markdown or asciidoc (default: auto-detected from extension)"
      flag "--llm-base-url", arg: "URL",    desc: "OpenAI Compatible API base URL (env: SLIDICT_LLM_BASE_URL)"
      flag "--llm-api-key",  arg: "KEY",    desc: "API key for the LLM endpoint (env: SLIDICT_LLM_API_KEY)"
      # rubocop:disable Layout/HashAlignment -- source-only line wrap, desc stays a single displayed line
      flag "--llm-model", arg: "NAME",
           desc: "Model name to request (env: SLIDICT_LLM_MODEL); omit to list available models"
      # rubocop:enable Layout/HashAlignment
      flag "--translate",    arg: "LANG",   desc: "Translate findings into the given language (e.g. Japanese)"
      flag "-h", "--help",                  desc: "Show this help"

      def run(argv)
        options = parse(argv)
        return print_help if options[:help] || options[:path].nil?
        return file_not_found(options[:path]) unless File.exist?(options[:path])

        run_lint(options)
      rescue ArgumentError => e
        print_usage_error(e)
      rescue Slidict::Lint::Linter::Error, Llm::Client::Error => e
        print_error(e)
      end

      private

      def run_lint(options)
        config = build_config(options)
        return llm_required unless config.llm_enabled?
        return print_available_models(config) if config.model.nil?

        print_findings(lint(options, config))
      end

      def lint(options, config)
        @linter_factory.call(config).lint(File.read(options[:path]), format: format_for(options), translate: options[:translate])
      end

      def print_usage_error(error)
        print_error(error)
        @output.puts
        print_help
        FAILURE
      end

      def print_error(error)
        @output.puts "Error: #{error.message}"
        FAILURE
      end

      def parse(argv)
        args = argv.dup
        options = { path: extract_path!(args) }
        parse_flags!(args, options)
        options
      end

      def extract_path!(args)
        args.shift unless args.first.to_s.start_with?("-")
      end

      def fetch_value!(args, option)
        value = args.shift
        raise ArgumentError, "#{option} requires a value" if value.nil? || value.start_with?("-")

        value
      end

      def build_config(options)
        Config.from_env.merge(
          base_url: options[:llm_base_url],
          api_key: options[:llm_api_key],
          model: options[:llm_model]
        )
      end

      def default_linter(config)
        client = Llm::Client.new(base_url: config.base_url, api_key: config.api_key, model: config.model)
        Slidict::Lint::Linter.new(client: client)
      end

      def format_for(options)
        return options[:format] if options[:format]

        ASCIIDOC_EXTENSIONS.include?(File.extname(options[:path]).downcase) ? "asciidoc" : "markdown"
      end

      def print_findings(findings)
        @output.puts(findings.empty? ? "No issues found." : @renderer.render(findings))
        SUCCESS
      end

      def file_not_found(path)
        @output.puts "Error: file not found: #{path}"
        FAILURE
      end

      def print_available_models(config)
        client = Llm::Client.new(base_url: config.base_url, api_key: config.api_key, model: nil)
        models = client.list_models
        if models.empty?
          @output.puts "No models available at #{config.base_url}"
        else
          @output.puts "Available models (specify one with --llm-model NAME or SLIDICT_LLM_MODEL=NAME):"
          models.each { |m| @output.puts "  #{m}" }
        end
        SUCCESS
      rescue Llm::Client::Error => e
        print_error(e)
      end

      def llm_required
        @output.puts "Error: lint requires an LLM endpoint (--llm-base-url or SLIDICT_LLM_BASE_URL)"
        FAILURE
      end

      usage do
        <<~USAGE
          Usage: slidict lint <file> [options]
          Diagnoses whether a slide deck's structure will land with its audience.
          #{flags_help}
        USAGE
      end
    end
  end
end

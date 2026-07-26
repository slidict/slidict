# frozen_string_literal: true

require "fileutils"
require "pathname"

module Slidict
  module Cli
    class App
      include Options

      # Keyed by the same symbols as the parsed CLI options (options[:topic],
      # etc.), so a missing answer's question text can be looked up directly
      # by `questions_for`.
      QUESTIONS = {
        topic: "What would you like to talk about?",
        duration: "How long is the presentation?",
        audience: "Who is the audience?",
        goal: "What should the audience remember or do?"
      }.freeze

      options input: -> { $stdin },
              output: -> { $stdout },
              renderer: -> { Output::Renderer.new },
              auth_client: -> { nil },
              credentials: -> { nil },
              sleeper: -> { Kernel },
              slides_command: -> { nil },
              server: -> { nil },
              lint_command: -> { nil }

      flag "--topic",        arg: "TEXT",  desc: "Presentation topic"
      flag "--duration",     arg: "TEXT",  desc: 'Presentation length, for example "5 minutes"'
      flag "--audience",     arg: "TEXT",  desc: "Target audience"
      flag "--goal",         arg: "TEXT",  desc: "Desired audience takeaway or action"
      flag "--text",         arg: "TEXT",  desc: "Source text to turn into slides"
      flag "--text-file",    arg: "PATH",  desc: "Read source text from a file"
      flag "--framework",    arg: "NAME",
                             desc: -> { "#{Output::Format.names.join(", ")} (default: slidev)\n(env: SLIDICT_FRAMEWORK)" }
      flag "--method",       arg: "ID",    desc: "Presentation method, for example scqa, prep, or pyramid\n" \
                                                  "(env: SLIDICT_METHOD)"
      flag "--language",     arg: "LANG",  desc: "Generate slide titles and bullets in the given language\n" \
                                                  "(e.g. Japanese); only affects LLM-generated slides"
      flag "--filename",     arg: "NAME",  desc: "File name under public/ (default: next sequential file)"
      flag "--llm-base-url", arg: "URL",   desc: "OpenAI Compatible API base URL (env: SLIDICT_LLM_BASE_URL).\n" \
                                                  "When omitted, the built-in slide template is used instead."
      flag "--llm-api-key",  arg: "KEY",   desc: "API key for the LLM endpoint (env: SLIDICT_LLM_API_KEY)"
      # rubocop:disable Layout/HashAlignment -- source-only line wrap, desc stays a single displayed line
      flag "--llm-model", arg: "NAME",
           desc: "Model name to request (env: SLIDICT_LLM_MODEL); omit to list available models"
      # rubocop:enable Layout/HashAlignment
      flag "--no-llm",                     desc: "Skip the LLM call and use the built-in slide template"
      flag "--publish",                    desc: "Publish the generated slides to slidict.io as a draft\n" \
                                                  "(requires `slidict auth`; creates a new slide, or edits\n" \
                                                  "an existing one when --slide-id is given)"
      # rubocop:disable Layout/HashAlignment -- source-only line wrap, desc stays a single displayed line
      flag "--slide-id", arg: "ID",
           desc: "Edit this existing draft instead of creating a new one\n(implies --publish)"
      # rubocop:enable Layout/HashAlignment
      flag "--slide-title",  arg: "TEXT",  desc: "Title for the published slide (default: --topic)"
      flag "--visibility",   arg: "VIS",   desc: "public, unlisted, or group_only (default: public)"
      flag "-o", "--output", arg: "PATH",  desc: "Output file (overrides --filename and the public/ default)"
      flag "-h", "--help",                 desc: "Show this help"

      def run(argv = [])
        options = parse(argv)
        return print_help if options[:help]
        return auth if options[:command] == "auth"
        return slides(options[:args]) if options[:command] == "slides"
        return serve(options[:args]) if options[:command] == "serve"
        return lint(options[:args]) if options[:command] == "lint"
        return list_methods if options[:command] == "list-methods"
        return show_method(options[:args]) if options[:command] == "show-method"
        return init if options[:command] == "init"

        config = build_config(options)
        return print_available_models(config) if config.llm_enabled? && config.model.nil?

        client = llm_client_for(config)
        return FAILURE if client && !verify_connection(client)

        options[:text] = read_source_text(options)
        raise ArgumentError, "--text and --text-file require an LLM endpoint" if options[:text] && !client

        questions = questions_for(client, options)
        deck = Deck.new(
          topic: source_topic(options) || ask(questions[:topic], options[:topic]),
          duration: options[:text] ? options[:duration] : ask(questions[:duration], options[:duration]),
          audience: options[:text] ? options[:audience] : ask(questions[:audience], options[:audience]),
          goal: options[:text] ? options[:goal] : ask(questions[:goal], options[:goal]),
          framework: options[:framework],
          presentation_method: options[:presentation_method],
          source: options[:text]
        )

        if client
          begin
            slides = client.generate_slides(deck, language: options[:language])
          rescue Llm::Client::Error => e
            @output.puts "Error: LLM request failed (#{e.message})"
            return FAILURE
          end
          deck = Deck.new(
            topic: deck.topic, duration: deck.duration, audience: deck.audience, goal: deck.goal,
            framework: deck.framework, slides: slides, presentation_method: deck.presentation_method,
            source: deck.source
          )
        end

        path = options[:output]
        content = @renderer.render(deck)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
        @output.puts "Created #{path}"

        return publish_to_slidict(deck, content, options) if options[:publish] || options[:slide_id]

        SUCCESS
      rescue ArgumentError => e
        @output.puts "Error: #{e.message}"
        @output.puts
        print_help
        FAILURE
      end

      private

      def read_source_text(options)
        raise ArgumentError, "specify only one of --text or --text-file" if options[:text] && options[:text_file]
        unless options[:text_file]
          raise ArgumentError, "source text must not be empty" if options.key?(:text) && options[:text].to_s.strip.empty?

          return options[:text]
        end

        File.read(options[:text_file]).tap do |text|
          raise ArgumentError, "source text must not be empty" if text.strip.empty?
        end
      rescue Errno::ENOENT, Errno::EACCES => e
        raise ArgumentError, "could not read #{options[:text_file]}: #{e.message}"
      end

      def source_topic(options)
        return options[:topic] unless options[:topic].to_s.strip.empty?
        return unless options[:text]

        options[:text].each_line.map(&:strip).find { |line| !line.empty? }&.sub(/\A#+\s*/, "")
      end

      def parse(argv)
        options = { framework: ENV["SLIDICT_FRAMEWORK"] || "slidev", method: ENV["SLIDICT_METHOD"] }
        args = argv.dup

        args.shift if args.first == "new"

        if args.first == "auth"
          args.shift
          raise ArgumentError, "auth does not accept options" unless args.empty?

          options[:command] = "auth"
          return options
        end

        if args.first == "slides"
          args.shift
          options[:command] = "slides"
          options[:args] = args
          return options
        end

        if args.first == "serve"
          args.shift
          options[:command] = "serve"
          options[:args] = args
          return options
        end

        if args.first == "lint"
          args.shift
          options[:command] = "lint"
          options[:args] = args
          return options
        end

        if args.first == "list-methods"
          args.shift
          raise ArgumentError, "list-methods does not accept options" unless args.empty?

          options[:command] = "list-methods"
          return options
        end

        if args.first == "show-method"
          args.shift
          options[:command] = "show-method"
          options[:args] = args
          return options
        end

        if args.first == "init"
          args.shift
          raise ArgumentError, "init does not accept options" unless args.empty?

          options[:command] = "init"
          return options
        end

        parse_flags!(args, options)

        options[:output] ||= output_path_for(options[:framework], options[:filename])
        options[:presentation_method] = method_for(options[:method])
        options
      end

      def build_config(options)
        Config.from_env.merge(
          base_url: options[:llm_base_url],
          api_key: options[:llm_api_key],
          model: options[:llm_model],
          enabled: options[:no_llm] ? false : nil
        )
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
        @output.puts "Error: LLM request failed (#{e.message})"
        FAILURE
      end

      def llm_client_for(config)
        return nil unless config.llm_enabled?

        Llm::Client.new(base_url: config.base_url, api_key: config.api_key, model: config.model)
      end

      def verify_connection(client)
        client.verify_connection!
        true
      rescue Llm::Client::Error => e
        @output.puts "Error: LLM request failed (#{e.message})"
        false
      end

      def auth
        client = @auth_client || External::SlidictIo::Auth.new
        credentials = @credentials || External::SlidictIo::Credentials.new

        device = client.request_device_code
        @output.puts "1. Open #{device[:verification_uri]} in your browser"
        @output.puts "2. Enter code: #{device[:user_code]}"
        @output.puts "3. Log in with GitHub"
        @output.puts "Waiting for GitHub authentication..."

        deadline = Time.now + device[:expires_in]
        loop do
          token = client.poll_token(device_code: device[:device_code])
          path = credentials.write_cli_token!(
            access_token: token.fetch("access_token"),
            token_type: token.fetch("token_type", "Bearer"),
            provider: token.fetch("provider", "github")
          )
          @output.puts "4. Saved CLI access token to #{path}"
          return SUCCESS
        rescue External::SlidictIo::Auth::Pending
          return login_expired if Time.now >= deadline

          @sleeper.sleep(device[:interval])
        end
      rescue External::SlidictIo::Auth::Error, KeyError => e
        @output.puts "Error: GitHub auth failed (#{e.message})"
        FAILURE
      end

      def slides(args)
        slides_command.run(args)
      end

      def serve(args)
        server.run(args)
      end

      def lint(args)
        lint_command.run(args)
      end

      def list_methods
        method_registry.all.each do |method|
          @output.puts format(
            "%-12<id>s %-28<name>s %<category>s",
            id: method.id, name: method.name, category: method.category
          )
        end
        SUCCESS
      end

      def show_method(args)
        raise ArgumentError, "show-method requires a method id" if args.empty?
        raise ArgumentError, "show-method accepts exactly one method id" unless args.size == 1

        method = method_registry.fetch(args.first)
        @output.puts "#{method.name} (#{method.id})"
        @output.puts "Category: #{method.category}"
        @output.puts "Description: #{method.description}"
        @output.puts "Suitable for:"
        method.suitable_for.each { |item| @output.puts "  - #{item}" }
        @output.puts "Slides:"
        method.slides.each_with_index { |slide, i| @output.puts "  #{i + 1}. #{slide.title}: #{slide.role}" }
        @output.puts "Review checklist:"
        method.review_checklist.each { |item| @output.puts "  - #{item}" }
        SUCCESS
      end

      def method_for(id)
        id ? method_registry.fetch(id) : nil
      end

      ENV_TEMPLATE = <<~ENV
        # Slidict configuration. CLI flags always take precedence over these
        # values; unset ones fall back to the built-in defaults. This file is
        # ignored by git (see .gitignore) so it's safe to put secrets here.

        # OpenAI Compatible API endpoint (required to enable LLM-generated slides).
        # SLIDICT_LLM_BASE_URL=https://api.openai.com/v1
        # SLIDICT_LLM_API_KEY=sk-...
        # SLIDICT_LLM_MODEL=gpt-4o-mini

        # Default --framework when it is not given on the command line.
        # SLIDICT_FRAMEWORK=slidev

        # Default --method when it is not given on the command line.
        # SLIDICT_METHOD=scqa
      ENV

      def init
        env_created = write_env_file
        @output.puts(env_created ? "Created .env" : ".env already exists, leaving it unchanged")

        gitignore_updated = ensure_env_gitignored
        @output.puts "Added .env to .gitignore" if gitignore_updated
        SUCCESS
      end

      def write_env_file
        return false if File.exist?(".env")

        File.write(".env", ENV_TEMPLATE)
        true
      end

      def ensure_env_gitignored
        return false if File.exist?(".gitignore") && File.readlines(".gitignore", chomp: true).include?(".env")

        File.open(".gitignore", "a") { |f| f.puts(".env") }
        true
      end

      def method_registry
        @method_registry ||= PresentationMethodRegistry.new
      end

      def publish_to_slidict(deck, content, options)
        slides_command.publish(
          id: options[:slide_id],
          title: options[:slide_title] || deck.topic,
          body: content,
          body_format: body_format_for(deck.framework),
          visibility: options[:visibility]
        )
      end

      def slides_command
        @slides_command ||= Slides.new(output: @output, credentials: @credentials, reauthenticate: method(:auth))
      end

      def server
        @server ||= Serve.new(output: @output)
      end

      def lint_command
        @lint_command ||= Lint.new(output: @output)
      end

      def body_format_for(framework)
        Output::Format.fetch(framework).body_format
      end

      def login_expired
        @output.puts "Error: GitHub auth timed out. Run `slidict auth` and try again."
        FAILURE
      end

      def fetch_value!(args, option)
        value = args.shift
        raise ArgumentError, "#{option} requires a value" if value.nil? || value.start_with?("-")

        value
      end

      def ask(question, provided)
        return provided unless provided.nil? || provided.strip.empty?

        @output.puts question
        @output.print "> "
        @input.gets&.chomp.to_s
      end

      # Translates only the questions that will actually be asked (those
      # whose option wasn't already given on the command line). Falls back to
      # the English questions if there's no client, no --language, nothing
      # left to ask, or a translation call fails -- this is a nicety, not
      # something worth aborting slide generation over.
      def questions_for(client, options)
        return QUESTIONS if options[:text]
        return QUESTIONS unless client && options[:language]

        missing = QUESTIONS.select { |key, _| options[key].to_s.strip.empty? }
        return QUESTIONS if missing.empty?

        translated = missing.transform_values { |text| client.translate_text(text, options[:language]) }
        QUESTIONS.merge(translated)
      rescue Llm::Client::Error => e
        @output.puts "Warning: could not translate questions into #{options[:language]} " \
                     "(#{e.message}); asking in English."
        QUESTIONS
      end

      usage do
        <<~USAGE
          Usage: slidict [new] [options]
          Usage: slidict init
          Usage: slidict auth
          Usage: slidict slides <list|show|create|edit> [options]
          Usage: slidict serve [sinatra options]
          Usage: slidict lint <file> [options]
          Usage: slidict list-methods
          Usage: slidict show-method <id>

          Generate presentation source files from a short conversation.

          Commands:
            init             Create a .env file for SLIDICT_LLM_* etc. and add it to .gitignore
            auth             Authenticate the CLI with GitHub and save a CLI access token
            slides           Manage your slides on slidict.io (run `slidict slides -h` for details)
            serve            Serve slide files from ./public with Sinatra
            lint             Check whether a slide deck's structure will land with its audience
                             (run `slidict lint -h` for details)
            list-methods     List available presentation methods
            show-method      Show details for one presentation method

          Options:
          #{flags_help}
        USAGE
      end

      def output_path_for(framework, filename)
        return File.join("public", normalize_filename(filename, framework)) if filename

        next_sequential_output_for(framework)
      end

      def normalize_filename(filename, framework)
        path = filename.to_s.strip
        raise ArgumentError, "--filename requires a relative path under public" if path.empty?
        raise ArgumentError, "--filename must be relative" if Pathname.new(path).absolute?
        raise ArgumentError, "--filename cannot include .." if Pathname.new(path).each_filename.any?("..")

        # --filename is already relative to public/, so drop a redundant leading
        # "public/" instead of nesting it twice (public/public/...).
        path = path.delete_prefix("public/")
        File.extname(path).empty? ? "#{path}#{default_extension_for(framework)}" : path
      end

      def next_sequential_output_for(framework)
        extension = default_extension_for(framework)
        number = 1
        loop do
          path = File.join("public", format("%03d%s", number, extension))
          return path unless File.exist?(path)

          number += 1
        end
      end

      def default_extension_for(framework)
        Output::Format.fetch(framework).extension
      end
    end
  end
end

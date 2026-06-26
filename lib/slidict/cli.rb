# frozen_string_literal: true

module Slidict
  class CLI
    DEFAULT_OUTPUT = "slides.md"
    DEFAULT_OUTPUT_BY_FRAMEWORK = {
      "slidev" => "slides.md",
      "marp" => "slides.md",
      "asciidoctor-revealjs" => "slides.adoc"
    }.freeze

    def initialize(input: $stdin, output: $stdout, renderer: MarkdownRenderer.new, auth_client: nil,
                   credentials: nil, sleeper: Kernel)
      @input = input
      @output = output
      @renderer = renderer
      @auth_client = auth_client
      @credentials = credentials
      @sleeper = sleeper
    end

    def run(argv = [])
      options = parse(argv)
      return print_help if options[:help]
      return login if options[:command] == "login"

      config = build_config(options)
      client = llm_client_for(config)
      return 1 if client && !verify_connection(client)

      deck = Deck.new(
        topic: ask("What would you like to talk about?", options[:topic]),
        duration: ask("How long is the presentation?", options[:duration]),
        audience: ask("Who is the audience?", options[:audience]),
        goal: ask("What should the audience remember or do?", options[:goal]),
        framework: options[:framework]
      )

      if client
        begin
          slides = client.generate_slides(deck)
        rescue LLMClient::Error => error
          @output.puts "Error: LLM request failed (#{error.message})"
          return 1
        end
        deck = Deck.new(
          topic: deck.topic, duration: deck.duration, audience: deck.audience, goal: deck.goal,
          framework: deck.framework, slides: slides
        )
      end

      path = options[:output]
      File.write(path, @renderer.render(deck))
      @output.puts "Created #{path}"
      0
    rescue ArgumentError => error
      @output.puts "Error: #{error.message}"
      @output.puts
      print_help
      1
    end

    private

    def parse(argv)
      options = { framework: "slidev" }
      args = argv.dup

      if args.first == "login"
        args.shift
        raise ArgumentError, "login does not accept options" unless args.empty?

        options[:command] = "login"
        return options
      end

      until args.empty?
        case (arg = args.shift)
        when "-h", "--help"
          options[:help] = true
        when "-o", "--output"
          options[:output] = fetch_value!(args, arg)
        when "--topic"
          options[:topic] = fetch_value!(args, arg)
        when "--duration"
          options[:duration] = fetch_value!(args, arg)
        when "--audience"
          options[:audience] = fetch_value!(args, arg)
        when "--goal"
          options[:goal] = fetch_value!(args, arg)
        when "--framework"
          options[:framework] = fetch_value!(args, arg)
        when "--llm-base-url"
          options[:llm_base_url] = fetch_value!(args, arg)
        when "--llm-api-key"
          options[:llm_api_key] = fetch_value!(args, arg)
        when "--llm-model"
          options[:llm_model] = fetch_value!(args, arg)
        when "--no-llm"
          options[:no_llm] = true
        else
          raise ArgumentError, "unknown option #{arg}"
        end
      end

      options[:output] ||= default_output_for(options[:framework])
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

    def llm_client_for(config)
      return nil unless config.llm_enabled?

      LLMClient.new(base_url: config.base_url, api_key: config.api_key, model: config.model)
    end

    def verify_connection(client)
      client.verify_connection!
      true
    rescue LLMClient::Error => error
      @output.puts "Error: LLM request failed (#{error.message})"
      false
    end

    def login
      client = @auth_client || AuthClient.new
      credentials = @credentials || Credentials.new

      device = client.request_device_code
      @output.puts "1. Open #{device[:verification_uri]} in your browser"
      @output.puts "2. Enter code: #{device[:user_code]}"
      @output.puts "3. Log in with GitHub"
      @output.puts "Waiting for GitHub authentication..."

      deadline = Time.now + device[:expires_in]
      loop do
        begin
          token = client.poll_token(device_code: device[:device_code])
          path = credentials.write_cli_token!(
            access_token: token.fetch("access_token"),
            token_type: token.fetch("token_type", "Bearer"),
            provider: token.fetch("provider", "github")
          )
          @output.puts "4. Saved CLI access token to #{path}"
          return 0
        rescue AuthClient::Pending
          return login_expired if Time.now >= deadline

          @sleeper.sleep(device[:interval])
        end
      end
    rescue AuthClient::Error, KeyError => error
      @output.puts "Error: GitHub login failed (#{error.message})"
      1
    end

    def login_expired
      @output.puts "Error: GitHub login timed out. Run `slidict login` and try again."
      1
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

    def print_help
      @output.puts <<~HELP
        Usage: slidict [options]
        Usage: slidict login

        Generate presentation source files from a short conversation.

        Commands:
            login            Authenticate the CLI with GitHub and save a CLI access token

        Options:
            --topic TEXT       Presentation topic
            --duration TEXT    Presentation length, for example "5 minutes"
            --audience TEXT    Target audience
            --goal TEXT        Desired audience takeaway or action
            --framework NAME   slidev, marp, or asciidoctor-revealjs (default: slidev)
            --llm-base-url URL OpenAI Compatible API base URL (env: SLIDICT_LLM_BASE_URL).
                               When omitted, the built-in slide template is used instead.
            --llm-api-key KEY  API key for the LLM endpoint (env: SLIDICT_LLM_API_KEY)
            --llm-model NAME   Model name to request (env: SLIDICT_LLM_MODEL, default: gpt-4o-mini)
            --no-llm           Skip the LLM call and use the built-in slide template
        -o, --output PATH      Output file (default depends on --framework)
        -h, --help             Show this help
      HELP
      0
    end

    def default_output_for(framework)
      DEFAULT_OUTPUT_BY_FRAMEWORK.fetch(framework.to_s.downcase, DEFAULT_OUTPUT)
    end
  end
end

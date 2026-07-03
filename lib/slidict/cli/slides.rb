# frozen_string_literal: true

module Slidict
  module Cli
    # Implements the `slidict slides <list|show|create|edit>` subcommands.
    class Slides
      include Options

      options output: Options::MISSING,
              credentials: -> { External::SlidictIo::Credentials.new },
              client: -> { nil },
              reauthenticate: -> { nil }

      # rubocop:disable Layout/HashAlignment -- source-only line wraps below, kept short rather than column-aligned
      flag "--page", arg: "N",
           coerce: ->(v) { Integer(v) }, desc: "Page number (20 slides per page)", group: :list
      # rubocop:enable Layout/HashAlignment
      flag "-h", "--help",              desc: "Show this help", group: :list

      flag "--title",      arg: "TEXT", desc: "Slide title", group: :body_options
      flag "--body",       arg: "TEXT", desc: "Slide body text", group: :body_options
      # rubocop:disable Layout/HashAlignment -- source-only line wraps below, kept short rather than column-aligned
      flag "--file",       arg: "PATH", desc: "Read the slide body from a file (instead of --body)",
           group: :body_options
      flag "--body-format", arg: "FORMAT", desc: "asciidoc or markdown (default: auto-detected from body)",
           group: :body_options
      # rubocop:enable Layout/HashAlignment
      flag "--visibility", arg: "VIS",  desc: "public, unlisted, or group_only (default: public)", group: :body_options
      flag "-h", "--help",              desc: "Show this help", group: :body_options

      def run(argv)
        options = parse(argv)
        return print_help if options[:help] || options[:subcommand].nil?

        send(options[:subcommand], options)
      rescue ArgumentError => e
        @output.puts "Error: #{e.message}"
        @output.puts
        print_help
        FAILURE
      end

      # Creates or edits a draft directly, bypassing argv parsing (and its
      # "looks like a flag" checks, which would reject body text such as
      # YAML frontmatter that happens to start with "-").
      def publish(body:, id: nil, title: nil, body_format: nil, visibility: nil)
        options = { id: id, title: title, body: body, body_format: body_format, visibility: visibility }
        id ? edit(options) : create(options)
      end

      private

      def parse(argv)
        args = argv.dup
        subcommand = args.shift
        return { help: true } if subcommand.nil? || %w[-h --help].include?(subcommand)

        case subcommand
        when "list" then parse_list(args)
        when "show" then parse_show(args)
        when "create" then parse_create(args)
        when "edit" then parse_edit(args)
        else raise ArgumentError, "unknown slides command #{subcommand}"
        end
      end

      def parse_list(args)
        options = { subcommand: :list }
        parse_flags!(args, options, :list)
        options
      end

      def parse_show(args)
        id = args.shift
        raise ArgumentError, "show requires a slide id" if id.nil?
        raise ArgumentError, "unknown option #{args.first}" unless args.empty?

        { subcommand: :show, id: id }
      end

      def parse_create(args)
        options = { subcommand: :create }
        parse_body_options!(args, options)
        options
      end

      def parse_edit(args)
        id = args.shift
        raise ArgumentError, "edit requires a slide id" if id.nil?

        options = { subcommand: :edit, id: id }
        parse_body_options!(args, options)
        options
      end

      def parse_body_options!(args, options)
        parse_flags!(args, options, :body_options)
        raise ArgumentError, "specify only one of --body or --file" if options[:body] && options[:file]
      end

      # Does not reject values starting with "-": body text or titles may
      # legitimately start with a dash (e.g. YAML frontmatter), and a genuinely
      # missing value still surfaces as an "unknown option" error from the
      # next iteration of the parse loop, or a nil check below.
      def fetch_value!(args, option)
        value = args.shift
        raise ArgumentError, "#{option} requires a value" if value.nil?

        value
      end

      def list(options)
        with_reauth_retry do
          print_slide_list(client.list(page: options[:page]))
          SUCCESS
        end
      end

      def show(options)
        with_reauth_retry do
          print_slide_detail(client.show(options[:id]))
          SUCCESS
        rescue External::SlidictIo::Client::NotFound
          @output.puts "Error: slide not found"
          FAILURE
        end
      end

      def create(options)
        body = read_body(options)
        raise ArgumentError, "create requires --body or --file" if body.to_s.strip.empty?

        submit("Created") do
          client.create(title: options[:title], body: body, body_format: options[:body_format],
                        visibility: options[:visibility])
        end
      end

      def edit(options)
        submit("Updated") do
          client.update(options[:id], title: options[:title], body: read_body(options),
                                      body_format: options[:body_format], visibility: options[:visibility])
        end
      end

      def submit(verb)
        with_reauth_retry do
          slide = yield
          @output.puts "#{verb} slide ##{slide["id"]} (draft)"
          print_slide_detail(slide)
          SUCCESS
        rescue External::SlidictIo::Client::NotFound
          @output.puts "Error: slide not found"
          FAILURE
        rescue External::SlidictIo::Client::NotEditable
          @output.puts "Error: this slide is already published. Edit it from the Web UI instead."
          FAILURE
        rescue External::SlidictIo::Client::RateLimited
          print_rate_limited
        rescue External::SlidictIo::Client::Unprocessable => e
          print_unprocessable(e)
        end
      end

      # Shared by list/show/submit: on a 401 from an expired/invalid token,
      # silently re-authenticate once (via the injected reauthenticate flow)
      # and retry the same request before giving up.
      def with_reauth_retry
        reauthenticated = false
        begin
          yield
        rescue External::SlidictIo::Client::Unauthorized => e
          if !reauthenticated && reauthenticate!
            reauthenticated = true
            retry
          end
          print_client_error(e)
        rescue External::SlidictIo::Client::Error => e
          print_client_error(e)
        end
      end

      def read_body(options)
        return options[:body] unless options[:file]

        File.read(options[:file])
      rescue Errno::ENOENT, Errno::EACCES => e
        raise ArgumentError, "could not read #{options[:file]}: #{e.message}"
      end

      def client
        @client ||= begin
          token = @credentials.read_cli_token
          token = @credentials.read_cli_token if token.nil? && reauthenticate!
          raise ArgumentError, "not authenticated. Run `slidict auth` first." unless token

          External::SlidictIo::Client.new(access_token: token[:access_token], token_type: token[:token_type])
        end
      end

      # Triggers the injected login flow (see Slidict::Cli::App#auth) and clears the
      # memoized client so the next call to `client` picks up the fresh token.
      def reauthenticate!
        return false unless @reauthenticate

        @client = nil
        @reauthenticate.call.zero?
      end

      def print_slide_list(result)
        slides = result["slides"] || []
        if slides.empty?
          @output.puts "No slides found."
          return
        end

        slides.each do |slide|
          @output.puts "##{slide["id"]} [#{slide["status"]}/#{slide["visibility"]}] " \
                       "#{slide["title"]} (updated_at: #{slide["updated_at"]})"
        end
        @output.puts "(more slides available, use --page to see the next page)" if result["has_more"]
      end

      def print_slide_detail(slide)
        @output.puts "##{slide["id"]} #{slide["title"]}"
        @output.puts "status: #{slide["status"]}  visibility: #{slide["visibility"]}  " \
                     "updated_at: #{slide["updated_at"]}"
        @output.puts
        @output.puts slide["body"]
      end

      def print_rate_limited
        @output.puts "Error: rate limited. Create/edit is limited to once per minute. Wait and try again."
        FAILURE
      end

      def print_unprocessable(error)
        @output.puts "Error: #{error.message}"
        error.errors.each { |message| @output.puts "  - #{message}" }
        FAILURE
      end

      def print_client_error(error)
        @output.puts "Error: #{error.message}"
        FAILURE
      end

      usage do
        <<~USAGE
          Usage: slidict slides <command> [options]

          Commands:
            list [--page N]      List your slides (20 per page)
            show <id>             Show a slide's details and body
            create [options]      Create a new draft slide
            edit <id> [options]   Edit an existing draft slide

          Create/edit options:
          #{flags_help(:body_options)}

          Note: slides are always created/edited as drafts. Publish from the Web UI.
        USAGE
      end
    end
  end
end

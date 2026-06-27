# frozen_string_literal: true

module Slidict
  # Implements the `slidict slides <list|show|create|edit>` subcommands.
  class SlidesCommand
    def initialize(output:, credentials: nil, client: nil)
      @output = output
      @credentials = credentials || Credentials.new
      @client = client
    end

    def run(argv)
      options = parse(argv)
      return print_help if options[:help] || options[:subcommand].nil?

      send(options[:subcommand], options)
    rescue ArgumentError => e
      @output.puts "Error: #{e.message}"
      @output.puts
      print_help
      1
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
      until args.empty?
        case (arg = args.shift)
        when "--page" then options[:page] = Integer(fetch_value!(args, arg))
        when "-h", "--help" then options[:help] = true
        else raise ArgumentError, "unknown option #{arg}"
        end
      end
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
      until args.empty?
        case (arg = args.shift)
        when "--title" then options[:title] = fetch_value!(args, arg)
        when "--body" then options[:body] = fetch_value!(args, arg)
        when "--file" then options[:file] = fetch_value!(args, arg)
        when "--body-format" then options[:body_format] = fetch_value!(args, arg)
        when "--visibility" then options[:visibility] = fetch_value!(args, arg)
        when "-h", "--help" then options[:help] = true
        else raise ArgumentError, "unknown option #{arg}"
        end
      end
      raise ArgumentError, "specify only one of --body or --file" if options[:body] && options[:file]
    end

    def fetch_value!(args, option)
      value = args.shift
      raise ArgumentError, "#{option} requires a value" if value.nil? || value.start_with?("-")

      value
    end

    def list(options)
      print_slide_list(client.list(page: options[:page]))
      0
    rescue SlidesClient::Error => e
      print_client_error(e)
    end

    def show(options)
      print_slide_detail(client.show(options[:id]))
      0
    rescue SlidesClient::NotFound
      @output.puts "Error: slide not found"
      1
    rescue SlidesClient::Error => e
      print_client_error(e)
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
      slide = yield
      @output.puts "#{verb} slide ##{slide["id"]} (draft)"
      print_slide_detail(slide)
      0
    rescue SlidesClient::NotFound
      @output.puts "Error: slide not found"
      1
    rescue SlidesClient::NotEditable
      @output.puts "Error: this slide is already published. Edit it from the Web UI instead."
      1
    rescue SlidesClient::RateLimited
      print_rate_limited
    rescue SlidesClient::Unprocessable => e
      print_unprocessable(e)
    rescue SlidesClient::Error => e
      print_client_error(e)
    end

    def read_body(options)
      return File.read(options[:file]) if options[:file]

      options[:body]
    end

    def client
      @client ||= begin
        token = @credentials.read_cli_token
        raise ArgumentError, "not authenticated. Run `slidict auth` first." unless token

        SlidesClient.new(access_token: token[:access_token], token_type: token[:token_type])
      end
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
      @output.puts "status: #{slide["status"]}  visibility: #{slide["visibility"]}  updated_at: #{slide["updated_at"]}"
      @output.puts
      @output.puts slide["body"]
    end

    def print_rate_limited
      @output.puts "Error: rate limited. Create/edit is limited to once per minute. Wait and try again."
      1
    end

    def print_unprocessable(error)
      @output.puts "Error: #{error.message}"
      error.errors.each { |message| @output.puts "  - #{message}" }
      1
    end

    def print_client_error(error)
      @output.puts "Error: #{error.message}"
      1
    end

    def print_help
      @output.puts <<~HELP
        Usage: slidict slides <command> [options]

        Commands:
          list [--page N]      List your slides (20 per page)
          show <id>             Show a slide's details and body
          create [options]      Create a new draft slide
          edit <id> [options]   Edit an existing draft slide

        Create/edit options:
            --title TEXT         Slide title
            --body TEXT          Slide body text
            --file PATH          Read the slide body from a file (instead of --body)
            --body-format FORMAT asciidoc or markdown (default: auto-detected from body)
            --visibility VIS     public, unlisted, or group_only (default: public)
        -h, --help                Show this help

        Note: slides are always created/edited as drafts. Publish from the Web UI.
      HELP
      0
    end
  end
end

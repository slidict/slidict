# frozen_string_literal: true

require "stringio"
require "tmpdir"

RSpec.describe Slidict::Cli::App do
  let(:output) { StringIO.new }
  let(:input) { StringIO.new }
  let(:cli) { described_class.new(input: input, output: output) }

  describe "#run" do
    it "writes a slides file from the given options" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run([
                           "--topic", "Observability",
                           "--duration", "10 minutes",
                           "--audience", "SREs",
                           "--goal", "adopt the checklist",
                           "--output", path
                         ])

        expect(status).to eq(0)
        expect(File.exist?(path)).to be(true)
        expect(File.read(path)).to include("# Observability")
        expect(output.string).to include("Created #{path}")
      end
    end

    it "defaults the output path to the next sequential public file" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          cli.run(["--topic", "x", "--duration", "x", "--audience", "x", "--goal", "x"])

          expect(File.exist?("public/001.md")).to be(true)
        end
      end
    end

    it "uses a framework-specific extension for the sequential output path" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          cli.run([
                    "--topic", "Observability",
                    "--duration", "10 minutes",
                    "--audience", "SREs",
                    "--goal", "adopt the checklist",
                    "--framework", "asciidoctor-revealjs"
                  ])

          expect(File.exist?("public/001.adoc")).to be(true)
          expect(File.read("public/001.adoc")).to include("= Observability")
        end
      end
    end

    it "uses --filename under public and appends the framework extension" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          cli.run([
                    "--topic", "Observability",
                    "--duration", "10 minutes",
                    "--audience", "SREs",
                    "--goal", "adopt the checklist",
                    "--filename", "team/demo"
                  ])

          expect(File.exist?("public/team/demo.md")).to be(true)
          expect(File.read("public/team/demo.md")).to include("# Observability")
        end
      end
    end

    it "does not duplicate public/ when --filename already starts with it" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          cli.run([
                    "--topic", "Observability",
                    "--duration", "10 minutes",
                    "--audience", "SREs",
                    "--goal", "adopt the checklist",
                    "--filename", "public/demo"
                  ])

          expect(File.exist?("public/demo.md")).to be(true)
          expect(File.exist?("public/public/demo.md")).to be(false)
        end
      end
    end

    it "increments the default output filename when a sequential file exists" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p("public")
          File.write("public/001.md", "existing")

          cli.run(["--topic", "x", "--duration", "x", "--audience", "x", "--goal", "x"])

          expect(File.read("public/001.md")).to eq("existing")
          expect(File.exist?("public/002.md")).to be(true)
        end
      end
    end

    it "prompts for any answer that was not passed as an option" do
      input.string = "Observability\n10 minutes\nSREs\nadopt the checklist\n"
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run(["--output", path])

        expect(output.string).to include("What would you like to talk about?")
        expect(File.read(path)).to include("# Observability")
      end
    end

    it "runs the GitHub CLI auth device flow and stores a CLI access token" do
      client = Class.new do
        def request_device_code
          {
            device_code: "device-123",
            user_code: "ABCD-EFGH",
            verification_uri: "https://slidict.io/cli/activate",
            interval: 1,
            expires_in: 600
          }
        end

        def poll_token(device_code:)
          if device_code == "device-123" && !@pending_seen
            @pending_seen = true
            raise Slidict::External::SlidictIo::Auth::Pending
          end

          { "access_token" => "cli-token", "token_type" => "Bearer", "provider" => "github" }
        end
      end.new
      credentials = instance_double(Slidict::External::SlidictIo::Credentials)
      sleeper = double("sleeper", sleep: nil)
      cli = described_class.new(
        input: input, output: output, auth_client: client, credentials: credentials, sleeper: sleeper
      )

      allow(credentials).to receive(:write_cli_token!)
        .with(access_token: "cli-token", token_type: "Bearer", provider: "github")
        .and_return("/tmp/slidict/credentials.json")

      status = cli.run(["auth"])

      expect(status).to eq(0)
      expect(output.string).to include("Open https://slidict.io/cli/activate in your browser")
      expect(output.string).to include("Enter code: ABCD-EFGH")
      expect(output.string).to include("Log in with GitHub")
      expect(output.string).to include("Saved CLI access token to /tmp/slidict/credentials.json")
    end

    it "prints an error when auth options are passed" do
      status = cli.run(["auth", "--topic", "x"])

      expect(status).to eq(1)
      expect(output.string).to include("Error: auth does not accept options")
    end

    it "uses a presentation method template when --method is given without an LLM" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run([
                           "--topic", "Market expansion", "--duration", "10 minutes",
                           "--audience", "Executives", "--goal", "approve the plan",
                           "--method", "scqa", "--output", path
                         ])

        expect(status).to eq(0)
        expect(File.read(path)).to include("# Situation")
        expect(File.read(path)).to include("# Complication")
      end
    end

    it "rejects an unknown presentation method before prompting" do
      status = cli.run(["--method", "unknown", "--output", "slides.md"])

      expect(status).to eq(1)
      expect(output.string).to include("Error: unknown presentation method unknown")
      expect(output.string).not_to include("What would you like to talk about?")
    end

    it "lists presentation methods" do
      status = cli.run(["list-methods"])

      expect(status).to eq(0)
      expect(output.string).to include("scqa")
      expect(output.string).to include("PREP")
      expect(output.string).to include("Pyramid Principle")
    end

    it "shows presentation method details" do
      status = cli.run(["show-method", "scqa"])

      expect(status).to eq(0)
      expect(output.string).to include("SCQA (scqa)")
      expect(output.string).to include("Situation")
      expect(output.string).to include("Review checklist")
    end

    it "creates a .env file and adds it to .gitignore" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          status = cli.run(["init"])

          expect(status).to eq(0)
          expect(File.read(".env")).to include("SLIDICT_LLM_BASE_URL")
          expect(File.read(".gitignore")).to include(".env")
          expect(output.string).to include("Created .env")
          expect(output.string).to include("Added .env to .gitignore")
        end
      end
    end

    it "leaves an existing .env and .gitignore entry alone" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          File.write(".env", "SLIDICT_LLM_MODEL=llama3\n")
          File.write(".gitignore", ".env\n")

          status = cli.run(["init"])

          expect(status).to eq(0)
          expect(File.read(".env")).to eq("SLIDICT_LLM_MODEL=llama3\n")
          expect(output.string).to include(".env already exists, leaving it unchanged")
          expect(output.string).not_to include("Added .env to .gitignore")
        end
      end
    end

    it "uses SLIDICT_FRAMEWORK and SLIDICT_METHOD as defaults when the flags are not given" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          with_env("SLIDICT_FRAMEWORK" => "marp", "SLIDICT_METHOD" => "scqa") do
            cli.run(["--topic", "x", "--duration", "x", "--audience", "x", "--goal", "x"])
          end

          expect(File.exist?("public/001.adoc")).to be(false)
          expect(File.exist?("public/001.md")).to be(true)
        end
      end
    end

    it "prefers --framework and --method over the environment variables" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          with_env("SLIDICT_FRAMEWORK" => "marp") do
            cli.run([
                      "--topic", "x", "--duration", "x", "--audience", "x", "--goal", "x",
                      "--framework", "asciidoctor-revealjs"
                    ])
          end

          expect(File.exist?("public/001.adoc")).to be(true)
        end
      end
    end

    it "prints help and returns 0 when -h is given" do
      status = cli.run(["-h"])

      expect(status).to eq(0)
      expect(output.string).to include("Usage: slidict [new] [options]")
    end

    it "prints an error and help when an unknown option is given" do
      status = cli.run(["--bogus"])

      expect(status).to eq(1)
      expect(output.string).to include("Error: unknown option --bogus")
      expect(output.string).to include("Usage: slidict [new] [options]")
    end

    it "prints an error when an option is missing its value" do
      status = cli.run(["--topic"])

      expect(status).to eq(1)
      expect(output.string).to include("Error: --topic requires a value")
    end

    it "uses the built-in template when no llm-base-url is configured" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                  "--llm-api-key", "ollama", "--output", path
                ])

        expect(File.read(path)).to include("# Observability")
      end
    end

    it "uses LLM-generated slides when an llm-base-url is configured" do
      generated = [Slidict::Slide.new(title: "Generated title", bullets: %w[a b])]
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides).and_return(generated)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                  "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                  "--llm-model", "llama3", "--output", path
                ])

        expect(File.read(path)).to include("# Generated title")
        expect(File.read(path)).not_to include("# Observability")
      end
    end

    it "passes --language through to the LLM client's generate_slides call" do
      generated = [Slidict::Slide.new(title: "Generated title", bullets: %w[a b])]
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      expect_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides)
        .with(anything, language: "Japanese").and_return(generated)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                  "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                  "--llm-model", "llama3", "--language", "Japanese", "--output", path
                ])
      end
    end

    it "asks translated questions when --language is given and an LLM is configured" do
      generated = [Slidict::Slide.new(title: "Generated title", bullets: %w[a b])]
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides).and_return(generated)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:translate_text) do |_client, text, _language|
        { "What would you like to talk about?" => "トピックは何ですか?" }.fetch(text, text)
      end

      input.string = "Observability\n10 minutes\nSREs\nadopt the checklist\n"
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                  "--llm-model", "llama3", "--language", "Japanese", "--output", path
                ])

        expect(output.string).to include("トピックは何ですか?")
        expect(output.string).not_to include("What would you like to talk about?")
      end
    end

    it "only translates the questions that still need answering" do
      generated = [Slidict::Slide.new(title: "Generated title", bullets: %w[a b])]
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides).and_return(generated)
      expect_any_instance_of(Slidict::Llm::Client).to receive(:translate_text)
        .with(Slidict::Cli::App::QUESTIONS[:goal], "Japanese")
        .and_return("何を持ち帰ってほしいですか?")

      input.string = "adopt the checklist\n"
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--topic", "Observability", "--duration", "x", "--audience", "x",
                  "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                  "--llm-model", "llama3", "--language", "Japanese", "--output", path
                ])

        expect(output.string).to include("何を持ち帰ってほしいですか?")
      end
    end

    it "falls back to English questions when translation fails" do
      generated = [Slidict::Slide.new(title: "Generated title", bullets: %w[a b])]
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides).and_return(generated)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:translate_text)
        .and_raise(Slidict::Llm::Client::Error, "boom")

      input.string = "Observability\n10 minutes\nSREs\nadopt the checklist\n"
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run([
                           "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                           "--llm-model", "llama3", "--language", "Japanese", "--output", path
                         ])

        expect(status).to eq(0)
        expect(output.string).to include("Warning: could not translate questions into Japanese (boom)")
        expect(output.string).to include("What would you like to talk about?")
      end
    end

    it "does not translate questions when --language is not given" do
      generated = [Slidict::Slide.new(title: "Generated title", bullets: %w[a b])]
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides).and_return(generated)
      expect_any_instance_of(Slidict::Llm::Client).not_to receive(:translate_text)

      input.string = "Observability\n10 minutes\nSREs\nadopt the checklist\n"
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                  "--llm-model", "llama3", "--output", path
                ])
      end
    end

    it "prints an error and exits without writing a file when the LLM request fails" do
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::Llm::Client).to receive(:generate_slides)
        .and_raise(Slidict::Llm::Client::Error, "boom")

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run([
                           "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                           "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama",
                           "--llm-model", "llama3", "--output", path
                         ])

        expect(status).to eq(1)
        expect(output.string).to include("Error: LLM request failed (boom)")
        expect(File.exist?(path)).to be(false)
      end
    end

    it "checks the connection before asking any questions and exits without prompting on failure" do
      allow_any_instance_of(Slidict::Llm::Client).to receive(:verify_connection!)
        .and_raise(Slidict::Llm::Client::Error, "connection refused")
      expect_any_instance_of(Slidict::Llm::Client).not_to receive(:generate_slides)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run(["--llm-base-url", "http://localhost:11434/v1", "--llm-model", "llama3", "--output", path])

        expect(status).to eq(1)
        expect(output.string).to include("Error: LLM request failed (connection refused)")
        expect(output.string).not_to include("What would you like to talk about?")
        expect(File.exist?(path)).to be(false)
      end
    end

    it "lists available models when --llm-base-url is set but --llm-model is not" do
      llm_client = instance_double(Slidict::Llm::Client)
      allow(Slidict::Llm::Client).to receive(:new).and_return(llm_client)
      allow(llm_client).to receive(:list_models).and_return(%w[gemma2 llama3])

      Dir.mktmpdir do |dir|
        status = cli.run(["--llm-base-url", "http://localhost:11434/v1", "--output", File.join(dir, "slides.md")])

        expect(status).to eq(0)
        expect(output.string).to include("llama3")
        expect(output.string).to include("gemma2")
        expect(output.string).to include("--llm-model")
      end
    end

    it "publishes the generated slides as a new draft when --publish is given" do
      slides_command = instance_double(Slidict::Cli::Slides, publish: 0)
      cli = described_class.new(input: input, output: output, slides_command: slides_command)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run([
                           "--topic", "Observability", "--duration", "10 minutes",
                           "--audience", "SREs", "--goal", "adopt the checklist",
                           "--output", path, "--publish", "--visibility", "unlisted"
                         ])

        expect(status).to eq(0)
        expect(slides_command).to have_received(:publish) do |**kwargs|
          expect(kwargs[:id]).to be_nil
          expect(kwargs[:title]).to eq("Observability")
          expect(kwargs[:body_format]).to eq("markdown")
          expect(kwargs[:visibility]).to eq("unlisted")
          expect(kwargs[:body]).to include("# Observability")
        end
      end
    end

    it "edits an existing draft when --slide-id is given" do
      slides_command = instance_double(Slidict::Cli::Slides, publish: 0)
      cli = described_class.new(input: input, output: output, slides_command: slides_command)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.adoc")

        cli.run([
                  "--topic", "Observability", "--duration", "10 minutes",
                  "--audience", "SREs", "--goal", "adopt the checklist",
                  "--framework", "asciidoctor-revealjs", "--output", path, "--slide-id", "42"
                ])

        expect(slides_command).to have_received(:publish) do |**kwargs|
          expect(kwargs[:id]).to eq("42")
          expect(kwargs[:body_format]).to eq("asciidoc")
        end
      end
    end

    it "delegates the slides command to SlidesCommand" do
      slides_command = instance_double(Slidict::Cli::Slides, run: 0)
      cli = described_class.new(input: input, output: output, slides_command: slides_command)

      status = cli.run(["slides", "list", "--page", "2"])

      expect(status).to eq(0)
      expect(slides_command).to have_received(:run).with(["list", "--page", "2"])
    end

    it "delegates the serve command and passes arguments to the Sinatra server" do
      server = instance_double(Slidict::Cli::Serve, run: 0)
      cli = described_class.new(input: input, output: output, server: server)

      status = cli.run(["serve", "-p", "4567", "-o", "0.0.0.0"])

      expect(status).to eq(0)
      expect(server).to have_received(:run).with(["-p", "4567", "-o", "0.0.0.0"])
    end

    it "skips the LLM call when --no-llm is given even with a base URL" do
      expect(Slidict::Llm::Client).not_to receive(:new)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                  "--llm-base-url", "http://localhost:11434/v1", "--no-llm", "--output", path
                ])

        expect(File.read(path)).to include("# Observability")
      end
    end
  end
end

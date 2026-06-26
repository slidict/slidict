# frozen_string_literal: true

require "stringio"
require "tmpdir"

RSpec.describe Slidict::CLI do
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

    it "defaults the output path to slides.md" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          cli.run(["--topic", "x", "--duration", "x", "--audience", "x", "--goal", "x"])

          expect(File.exist?("slides.md")).to be(true)
        end
      end
    end

    it "uses a framework-specific default output path" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          cli.run([
                    "--topic", "Observability",
                    "--duration", "10 minutes",
                    "--audience", "SREs",
                    "--goal", "adopt the checklist",
                    "--framework", "asciidoctor-revealjs"
                  ])

          expect(File.exist?("slides.adoc")).to be(true)
          expect(File.read("slides.adoc")).to include("= Observability")
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

    it "runs the GitHub CLI login device flow and stores a CLI access token" do
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
            raise Slidict::AuthClient::Pending
          end

          { "access_token" => "cli-token", "token_type" => "Bearer", "provider" => "github" }
        end
      end.new
      credentials = instance_double(Slidict::Credentials)
      sleeper = double("sleeper", sleep: nil)
      cli = described_class.new(
        input: input, output: output, auth_client: client, credentials: credentials, sleeper: sleeper
      )

      allow(credentials).to receive(:write_cli_token!)
        .with(access_token: "cli-token", token_type: "Bearer", provider: "github")
        .and_return("/tmp/slidict/credentials.json")

      status = cli.run(["login"])

      expect(status).to eq(0)
      expect(output.string).to include("Open https://slidict.io/cli/activate in your browser")
      expect(output.string).to include("Enter code: ABCD-EFGH")
      expect(output.string).to include("Log in with GitHub")
      expect(output.string).to include("Saved CLI access token to /tmp/slidict/credentials.json")
    end

    it "prints an error when login options are passed" do
      status = cli.run(["login", "--topic", "x"])

      expect(status).to eq(1)
      expect(output.string).to include("Error: login does not accept options")
    end

    it "prints help and returns 0 when -h is given" do
      status = cli.run(["-h"])

      expect(status).to eq(0)
      expect(output.string).to include("Usage: slidict [options]")
    end

    it "prints an error and help when an unknown option is given" do
      status = cli.run(["--bogus"])

      expect(status).to eq(1)
      expect(output.string).to include("Error: unknown option --bogus")
      expect(output.string).to include("Usage: slidict [options]")
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
      allow_any_instance_of(Slidict::LLMClient).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::LLMClient).to receive(:generate_slides).and_return(generated)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        cli.run([
                  "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                  "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama", "--output", path
                ])

        expect(File.read(path)).to include("# Generated title")
        expect(File.read(path)).not_to include("# Observability")
      end
    end

    it "prints an error and exits without writing a file when the LLM request fails" do
      allow_any_instance_of(Slidict::LLMClient).to receive(:verify_connection!)
      allow_any_instance_of(Slidict::LLMClient).to receive(:generate_slides)
        .and_raise(Slidict::LLMClient::Error, "boom")

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run([
                           "--topic", "Observability", "--duration", "x", "--audience", "x", "--goal", "x",
                           "--llm-base-url", "http://localhost:11434/v1", "--llm-api-key", "ollama", "--output", path
                         ])

        expect(status).to eq(1)
        expect(output.string).to include("Error: LLM request failed (boom)")
        expect(File.exist?(path)).to be(false)
      end
    end

    it "checks the connection before asking any questions and exits without prompting on failure" do
      allow_any_instance_of(Slidict::LLMClient).to receive(:verify_connection!)
        .and_raise(Slidict::LLMClient::Error, "connection refused")
      expect_any_instance_of(Slidict::LLMClient).not_to receive(:generate_slides)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "slides.md")

        status = cli.run(["--llm-base-url", "http://localhost:11434/v1", "--output", path])

        expect(status).to eq(1)
        expect(output.string).to include("Error: LLM request failed (connection refused)")
        expect(output.string).not_to include("What would you like to talk about?")
        expect(File.exist?(path)).to be(false)
      end
    end

    it "skips the LLM call when --no-llm is given even with a base URL" do
      expect(Slidict::LLMClient).not_to receive(:new)

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

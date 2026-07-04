# frozen_string_literal: true

require "tmpdir"

RSpec.describe Slidict::Env do
  describe ".load!" do
    it "does nothing when the file does not exist" do
      Dir.mktmpdir do |dir|
        env = {}
        described_class.load!(File.join(dir, ".env"), env)

        expect(env).to eq({})
      end
    end

    it "loads KEY=VALUE pairs into the given env hash" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "SLIDICT_LLM_BASE_URL=http://localhost:11434/v1\nSLIDICT_LLM_MODEL=llama3\n")

        env = {}
        described_class.load!(path, env)

        expect(env["SLIDICT_LLM_BASE_URL"]).to eq("http://localhost:11434/v1")
        expect(env["SLIDICT_LLM_MODEL"]).to eq("llama3")
      end
    end

    it "ignores blank lines and comments" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "\n# a comment\nSLIDICT_FRAMEWORK=marp\n")

        env = {}
        described_class.load!(path, env)

        expect(env).to eq("SLIDICT_FRAMEWORK" => "marp")
      end
    end

    it "strips surrounding quotes and trailing inline comments" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".env")
        File.write(path, %(SLIDICT_LLM_API_KEY="sk-abc" # secret\nSLIDICT_METHOD='scqa'\n))

        env = {}
        described_class.load!(path, env)

        expect(env["SLIDICT_LLM_API_KEY"]).to eq("sk-abc")
        expect(env["SLIDICT_METHOD"]).to eq("scqa")
      end
    end

    it "does not override a key that is already set" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "SLIDICT_LLM_MODEL=llama3\n")

        env = { "SLIDICT_LLM_MODEL" => "gpt-4o" }
        described_class.load!(path, env)

        expect(env["SLIDICT_LLM_MODEL"]).to eq("gpt-4o")
      end
    end

    it "tolerates an export prefix" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "export SLIDICT_FRAMEWORK=slidev\n")

        env = {}
        described_class.load!(path, env)

        expect(env["SLIDICT_FRAMEWORK"]).to eq("slidev")
      end
    end
  end
end

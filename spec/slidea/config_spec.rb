# frozen_string_literal: true

RSpec.describe Slidea::Config do
  describe ".from_env" do
    it "uses defaults when no environment variables are set" do
      config = described_class.from_env({})

      expect(config.base_url).to be_nil
      expect(config.model).to eq("gpt-4o-mini")
      expect(config.api_key).to be_nil
      expect(config.llm_enabled?).to be(false)
    end

    it "reads settings from the environment" do
      config = described_class.from_env(
        "SLIDEA_LLM_BASE_URL" => "http://localhost:11434/v1",
        "SLIDEA_LLM_API_KEY" => "ollama",
        "SLIDEA_LLM_MODEL" => "llama3"
      )

      expect(config.base_url).to eq("http://localhost:11434/v1")
      expect(config.api_key).to eq("ollama")
      expect(config.model).to eq("llama3")
      expect(config.llm_enabled?).to be(true)
    end
  end

  describe "#merge" do
    it "overrides only the provided values" do
      config = described_class.from_env("SLIDEA_LLM_BASE_URL" => "http://localhost:11434/v1").merge(model: "gpt-4o")

      expect(config.base_url).to eq("http://localhost:11434/v1")
      expect(config.model).to eq("gpt-4o")
    end

    it "is not enabled without a base_url even if an api_key is set" do
      config = described_class.from_env("SLIDEA_LLM_API_KEY" => "key")

      expect(config.llm_enabled?).to be(false)
    end

    it "disables the LLM when enabled: false is given" do
      config = described_class.from_env("SLIDEA_LLM_BASE_URL" => "http://localhost:11434/v1").merge(enabled: false)

      expect(config.llm_enabled?).to be(false)
    end
  end
end

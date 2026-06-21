# frozen_string_literal: true

module Slidea
  class Config
    DEFAULT_MODEL = "gpt-4o-mini"

    attr_reader :base_url, :api_key, :model

    def initialize(base_url: nil, api_key: nil, model: DEFAULT_MODEL, enabled: true)
      @base_url = base_url
      @api_key = api_key
      @model = model
      @enabled = enabled
    end

    def self.from_env(env = ENV)
      new(
        base_url: env["SLIDEA_LLM_BASE_URL"],
        api_key: env["SLIDEA_LLM_API_KEY"],
        model: env["SLIDEA_LLM_MODEL"] || DEFAULT_MODEL
      )
    end

    def merge(base_url: nil, api_key: nil, model: nil, enabled: nil)
      self.class.new(
        base_url: base_url || @base_url,
        api_key: api_key || @api_key,
        model: model || @model,
        enabled: enabled.nil? ? @enabled : enabled
      )
    end

    # An llm-base-url is required to enable the LLM call; otherwise the
    # built-in slide template is used.
    def llm_enabled?
      @enabled && !base_url.to_s.strip.empty?
    end
  end
end

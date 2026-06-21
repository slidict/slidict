# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Slidea
  # Talks to any OpenAI Compatible API (OpenAI, Ollama, LM Studio, vLLM, etc.)
  # via the standard /chat/completions endpoint. Configure the target with
  # Slidea::Config (base_url, api_key, model).
  class LLMClient
    class Error < StandardError; end

    def initialize(base_url:, api_key:, model:)
      @base_url = base_url
      @api_key = api_key
      @model = model
    end

    # Checks that the endpoint is reachable before the (slower, more
    # expensive) chat completion request is made. Raises Error on failure.
    def verify_connection!
      uri = endpoint_uri("models")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      response = perform_request(uri, request)

      raise Error, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
    end

    def generate_slides(deck)
      content = chat_completion(prompt_for(deck))
      slides_from(content)
    end

    private

    def prompt_for(deck)
      <<~PROMPT
        You are an assistant that designs presentation slide outlines.
        Topic: #{deck.topic}
        Duration: #{deck.duration}
        Audience: #{deck.audience}
        Goal: #{deck.goal}

        Return exactly 5 slides as a JSON array. Each item must be an object with
        a "title" string and a "bullets" array of 2-4 short strings.
        Respond with the JSON array only: no commentary, no markdown code fences,
        and no reasoning or thinking content before or after it.
      PROMPT
    end

    def chat_completion(prompt)
      response = JSON.parse(post_chat_completion(prompt))
      content = response.dig("choices", 0, "message", "content")
      raise Error, "empty response from model" if content.to_s.strip.empty?

      content
    rescue JSON::ParserError => e
      raise Error, "could not parse model response: #{e.message}"
    end

    def post_chat_completion(prompt)
      uri = endpoint_uri("chat/completions")
      request = build_request(uri, prompt)
      response = perform_request(uri, request)

      raise Error, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def perform_request(uri, request)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: 5,
                      read_timeout: 30,
                      write_timeout: 30) do |http|
        http.request(request)
      end
    rescue StandardError => e
      raise Error, e.message
    end

    def endpoint_uri(path)
      base = @base_url.to_s.sub(%r{/+\z}, "")
      URI.join("#{base}/", path)
    end

    def build_request(uri, prompt)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request.body = JSON.generate(
        model: @model,
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7
      )
      request
    end

    def slides_from(content)
      parsed = JSON.parse(extract_json_array(content))
      raise Error, "expected a JSON array of slides" unless parsed.is_a?(Array)

      parsed.map do |item|
        Slide.new(title: item.fetch("title"), bullets: Array(item.fetch("bullets")))
      end
    rescue JSON::ParserError, KeyError => e
      raise Error, "could not parse model response: #{e.message}"
    end

    # Some models (especially reasoning models served through LM Studio or
    # Ollama) prepend or append thinking/reasoning text around the JSON
    # answer instead of returning it verbatim, so the array is extracted from
    # within the raw content rather than parsed as-is.
    def extract_json_array(content)
      content.enum_for(:scan, /\[/).each do
        start = Regexp.last_match.begin(0)
        candidate = json_array_from(content, start)
        return candidate if candidate
      end

      raise Error, "no JSON array found in model response"
    end

    def json_array_from(content, start)
      finish = start
      while (finish = content.index("]", finish))
        candidate = content[start..finish]
        return candidate if parses_to_array?(candidate)

        finish += 1
      end
      nil
    end

    def parses_to_array?(candidate)
      JSON.parse(candidate).is_a?(Array)
    rescue JSON::ParserError
      false
    end
  end
end

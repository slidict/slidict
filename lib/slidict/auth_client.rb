# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Slidict
  class AuthClient
    Error = Class.new(StandardError)
    Pending = Class.new(StandardError)

    DEFAULT_BASE_URL = "https://slidict.io"

    attr_reader :base_url

    def initialize(base_url: ENV.fetch("SLIDICT_AUTH_BASE_URL", DEFAULT_BASE_URL))
      @base_url = base_url
    end

    def request_device_code
      response = post_json("/api/cli/device/code", provider: "github")
      {
        device_code: fetch!(response, "device_code"),
        user_code: fetch!(response, "user_code"),
        verification_uri: response["verification_uri"] || "#{base_url}/cli/activate",
        interval: response.fetch("interval", 5).to_i,
        expires_in: response.fetch("expires_in", 600).to_i
      }
    end

    def poll_token(device_code:)
      response = post_json(
        "/api/cli/device/token",
        device_code: device_code,
        grant_type: "urn:ietf:params:oauth:grant-type:device_code"
      )
      return response if response["access_token"]

      error = response["error"].to_s
      raise Pending if %w[authorization_pending slow_down].include?(error)

      raise Error, response["error_description"] || error unless error.empty?

      raise Error, "token response did not include access_token"
    end

    private

    def post_json(path, payload)
      uri = URI.join(base_url, path)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      raise Error, body["error_description"] || body["error"] || "HTTP #{response.code}"
    rescue JSON::ParserError => e
      raise Error, "invalid JSON response: #{e.message}"
    rescue SystemCallError, Timeout::Error => e
      raise Error, e.message
    end

    def fetch!(hash, key)
      hash.fetch(key)
    rescue KeyError
      raise Error, "device code response did not include #{key}"
    end
  end
end

# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Slidict
  # Talks to the slidict.io CLI slides API using a CLI access token
  # (obtained via Slidict::AuthClient / `slidict auth`).
  class SlidesClient
    class Error < StandardError; end
    class Unauthorized < Error; end
    class Forbidden < Error; end
    class NotFound < Error; end
    class NotEditable < Error; end
    class RateLimited < Error; end

    # Raised for 422 responses other than "not_editable", carrying the API's validation errors.
    class Unprocessable < Error
      attr_reader :errors

      def initialize(message, errors: [])
        super(message)
        @errors = errors
      end
    end

    DEFAULT_BASE_URL = "https://slidict.io"

    attr_reader :base_url

    def initialize(access_token:, token_type: "Bearer", base_url: ENV.fetch("SLIDICT_AUTH_BASE_URL", DEFAULT_BASE_URL))
      @access_token = access_token
      @token_type = token_type
      @base_url = base_url
    end

    def list(page: nil)
      get_json("/api/cli/slides", query: page ? { page: page } : {})
    end

    def show(id)
      get_json("/api/cli/slides/#{id}")
    end

    def create(body:, title: nil, body_format: nil, visibility: nil)
      post_json("/api/cli/slides",
                slide_payload(title: title, body: body, body_format: body_format, visibility: visibility))
    end

    def update(id, body: nil, title: nil, body_format: nil, visibility: nil)
      patch_json("/api/cli/slides/#{id}",
                 slide_payload(title: title, body: body, body_format: body_format, visibility: visibility))
    end

    private

    def slide_payload(title:, body:, body_format:, visibility:)
      { title: title, body: body, body_format: body_format, visibility: visibility }.compact
    end

    def get_json(path, query: {})
      uri = URI.join(base_url, path)
      uri.query = URI.encode_www_form(query) unless query.empty?
      perform(uri, Net::HTTP::Get.new(uri))
    end

    def post_json(path, payload)
      uri = URI.join(base_url, path)
      perform(uri, build_request(Net::HTTP::Post.new(uri), payload))
    end

    def patch_json(path, payload)
      uri = URI.join(base_url, path)
      perform(uri, build_request(Net::HTTP::Patch.new(uri), payload))
    end

    def build_request(request, payload)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      request
    end

    def perform(uri, request)
      request["Accept"] = "application/json"
      request["Authorization"] = "#{@token_type} #{@access_token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      handle_response(response, body)
    rescue JSON::ParserError => e
      raise Error, "invalid JSON response: #{e.message}"
    rescue SystemCallError, Timeout::Error => e
      raise Error, e.message
    end

    ERROR_CLASSES_BY_STATUS = {
      "401" => Unauthorized,
      "403" => Forbidden,
      "404" => NotFound,
      "429" => RateLimited
    }.freeze

    def handle_response(response, body)
      return body if response.is_a?(Net::HTTPSuccess)
      return raise_unprocessable(body) if response.code == "422"

      error_class = ERROR_CLASSES_BY_STATUS.fetch(response.code, Error)
      raise error_class, body["error_description"] || body["error"] || "HTTP #{response.code}"
    end

    def raise_unprocessable(body)
      raise NotEditable, "not_editable" if body["error"] == "not_editable"

      raise Unprocessable.new(body["error"] || "unprocessable", errors: Array(body["errors"]))
    end
  end
end

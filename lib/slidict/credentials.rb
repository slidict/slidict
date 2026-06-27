# frozen_string_literal: true

require "fileutils"
require "json"

module Slidict
  class Credentials
    DEFAULT_PATH = File.expand_path("~/.config/slidict/credentials.json")

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    def write_cli_token!(access_token:, token_type: "Bearer", provider: "github")
      FileUtils.mkdir_p(File.dirname(@path), mode: 0o700)
      json = JSON.pretty_generate(
        "access_token" => access_token,
        "token_type" => token_type,
        "provider" => provider,
        "kind" => "cli_access_token"
      )
      File.write(@path, "#{json}\n", mode: "w", perm: 0o600)
      File.chmod(0o600, @path)
      @path
    end

    # Returns { access_token:, token_type: } or nil if no CLI access token is saved.
    def read_cli_token
      return nil unless File.exist?(@path)

      data = JSON.parse(File.read(@path))
      return nil unless data["kind"] == "cli_access_token" && data["access_token"]

      { access_token: data["access_token"], token_type: data.fetch("token_type", "Bearer") }
    rescue JSON::ParserError
      nil
    end
  end
end

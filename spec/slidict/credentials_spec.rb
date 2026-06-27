# frozen_string_literal: true

require "json"
require "tmpdir"

RSpec.describe Slidict::Credentials do
  it "writes only a CLI access token with private file permissions" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "slidict", "credentials.json")
      credentials = described_class.new(path: path)

      credentials.write_cli_token!(access_token: "cli-token", token_type: "Bearer", provider: "github")

      data = JSON.parse(File.read(path))
      expect(data).to eq(
        "access_token" => "cli-token",
        "token_type" => "Bearer",
        "provider" => "github",
        "kind" => "cli_access_token"
      )
      expect(format("%o", File.stat(path).mode & 0o777)).to eq("600")
    end
  end

  describe "#read_cli_token" do
    it "returns nil when no credentials file exists" do
      Dir.mktmpdir do |dir|
        credentials = described_class.new(path: File.join(dir, "slidict", "credentials.json"))

        expect(credentials.read_cli_token).to be_nil
      end
    end

    it "returns the saved access token and token type" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "slidict", "credentials.json")
        credentials = described_class.new(path: path)
        credentials.write_cli_token!(access_token: "cli-token", token_type: "Bearer", provider: "github")

        expect(credentials.read_cli_token).to eq(access_token: "cli-token", token_type: "Bearer")
      end
    end
  end
end

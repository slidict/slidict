# frozen_string_literal: true

RSpec.describe Slidict::SlidesClient do
  let(:client) { described_class.new(access_token: "cli-token", base_url: "https://slidict.io") }

  def stub_http_response(body, code: "200", message: "OK")
    response = Net::HTTPOK.new("1.1", code, message)
    allow(response).to receive(:body).and_return(body)
    http = instance_double(Net::HTTP, request: response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    response
  end

  def stub_error_response(klass, code, body)
    response = klass.new("1.1", code, "")
    allow(response).to receive(:body).and_return(body.to_json)
    http = instance_double(Net::HTTP, request: response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  describe "#list" do
    it "returns the parsed slide list" do
      stub_http_response({ "slides" => [{ "id" => 1, "title" => "A" }], "has_more" => false }.to_json)

      result = client.list

      expect(result["slides"].first["title"]).to eq("A")
    end

    it "sends the page as a query parameter" do
      response = stub_http_response({ "slides" => [], "has_more" => false }.to_json)
      allow(Net::HTTP::Get).to receive(:new).and_call_original

      client.list(page: 2)

      expect(Net::HTTP::Get).to have_received(:new) do |uri|
        expect(uri.query).to eq("page=2")
      end
      expect(response).to be_a(Net::HTTPOK)
    end
  end

  describe "#show" do
    it "returns the slide detail" do
      stub_http_response({ "id" => 1, "title" => "A", "body" => "hello" }.to_json)

      expect(client.show(1)["body"]).to eq("hello")
    end

    it "raises NotFound on a 404" do
      stub_error_response(Net::HTTPNotFound, "404", { "error" => "not_found" })

      expect { client.show(999) }.to raise_error(Slidict::SlidesClient::NotFound)
    end
  end

  describe "#create" do
    it "returns the created slide" do
      stub_http_response({ "id" => 1, "status" => "draft" }.to_json, code: "201", message: "Created")

      expect(client.create(body: "hello")["status"]).to eq("draft")
    end

    it "raises Unauthorized on a 401" do
      stub_error_response(Net::HTTPUnauthorized, "401", { "error" => "invalid_token" })

      expect { client.create(body: "hello") }.to raise_error(Slidict::SlidesClient::Unauthorized)
    end

    it "raises RateLimited on a 429" do
      stub_error_response(Net::HTTPTooManyRequests, "429", {})

      expect { client.create(body: "hello") }.to raise_error(Slidict::SlidesClient::RateLimited)
    end

    it "raises Unprocessable with the response errors on a generic 422" do
      stub_error_response(Net::HTTPUnprocessableEntity, "422", { "errors" => ["body can't be blank"] })

      expect { client.create(body: "") }.to raise_error(Slidict::SlidesClient::Unprocessable) do |error|
        expect(error.errors).to eq(["body can't be blank"])
      end
    end
  end

  describe "#update" do
    it "raises NotEditable when the slide is already published" do
      stub_error_response(Net::HTTPUnprocessableEntity, "422", { "error" => "not_editable" })

      expect { client.update(1, body: "hello") }.to raise_error(Slidict::SlidesClient::NotEditable)
    end

    it "raises Forbidden on a 403" do
      stub_error_response(Net::HTTPForbidden, "403", { "error" => "insufficient_scope" })

      expect { client.update(1, body: "hello") }.to raise_error(Slidict::SlidesClient::Forbidden)
    end
  end
end

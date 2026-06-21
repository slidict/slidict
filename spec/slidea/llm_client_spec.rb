# frozen_string_literal: true

RSpec.describe Slidea::LLMClient do
  let(:client) { described_class.new(base_url: "http://localhost:11434/v1", api_key: "ollama", model: "llama3") }
  let(:deck) { Slidea::Deck.new(topic: "Observability", duration: "5 minutes", audience: "SREs", goal: "adopt the checklist") }

  def stub_http_response(body, code: "200", message: "OK")
    response = Net::HTTPOK.new("1.1", code, message)
    allow(response).to receive(:body).and_return(body)
    http = instance_double(Net::HTTP, request: response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  describe "#verify_connection!" do
    it "does not raise when the endpoint responds successfully" do
      stub_http_response({ "data" => [] }.to_json)

      expect { client.verify_connection! }.not_to raise_error
    end

    it "raises an Error when the endpoint responds with a failure" do
      response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      allow(response).to receive(:body).and_return("")
      http = instance_double(Net::HTTP, request: response)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      expect { client.verify_connection! }.to raise_error(Slidea::LLMClient::Error, /400/)
    end

    it "raises an Error when the connection is refused" do
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED, "connection refused")

      expect { client.verify_connection! }.to raise_error(Slidea::LLMClient::Error)
    end
  end

  describe "#generate_slides" do
    it "parses a successful chat completion into slides" do
      content = [{ "title" => "Observability", "bullets" => ["Why it matters", "What changes"] }].to_json
      stub_http_response({ "choices" => [{ "message" => { "content" => content } }] }.to_json)

      slides = client.generate_slides(deck)

      expect(slides.size).to eq(1)
      expect(slides.first.title).to eq("Observability")
      expect(slides.first.bullets).to eq(["Why it matters", "What changes"])
    end

    it "raises an Error when the HTTP response is not successful" do
      response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      allow(response).to receive(:body).and_return("")
      http = instance_double(Net::HTTP, request: response)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      expect { client.generate_slides(deck) }.to raise_error(Slidea::LLMClient::Error, /400/)
    end

    it "raises an Error when the model response is not valid JSON" do
      stub_http_response({ "choices" => [{ "message" => { "content" => "not json" } }] }.to_json)

      expect { client.generate_slides(deck) }.to raise_error(Slidea::LLMClient::Error, /no JSON array found/)
    end

    it "extracts the JSON array even when the model wraps it in reasoning text" do
      json = [{ "title" => "Observability", "bullets" => ["a", "b"] }].to_json
      content = "<|channel|>thought<|message|>let me think...<|end|>#{json}\nDone."
      stub_http_response({ "choices" => [{ "message" => { "content" => content } }] }.to_json)

      slides = client.generate_slides(deck)

      expect(slides.first.title).to eq("Observability")
    end

    it "raises an Error when the network request fails" do
      allow(Net::HTTP).to receive(:start).and_raise(SocketError, "connection refused")

      expect { client.generate_slides(deck) }.to raise_error(Slidea::LLMClient::Error, /connection refused/)
    end
  end
end

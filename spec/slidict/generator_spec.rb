# frozen_string_literal: true

RSpec.describe Slidict::Generator do
  let(:client) { instance_double(Slidict::Llm::Client) }

  it "generates a deck and rendered content from source text" do
    slides = [Slidict::Slide.new(title: "要点", bullets: ["事実を保つ"])]
    allow(client).to receive(:generate_slides).and_return(slides)

    result = described_class.new(client: client).generate(
      text: "# 設計提案\n本文です", framework: "slidev", language: "Japanese"
    )

    expect(result.deck.topic).to eq("設計提案")
    expect(result.deck.source).to eq("# 設計提案\n本文です")
    expect(result.content).to include("# 要点", "- 事実を保つ")
    expect(client).to have_received(:generate_slides).with(an_instance_of(Slidict::Deck), language: "Japanese")
  end

  it "rejects empty source text" do
    expect { described_class.new(client: client).generate(text: "  ") }
      .to raise_error(ArgumentError, "text must not be empty")
  end
end

# frozen_string_literal: true

RSpec.describe Slidea::Deck do
  describe "#initialize" do
    it "falls back to defaults for blank answers" do
      deck = described_class.new(topic: "", duration: "", audience: "", goal: "")

      expect(deck.topic).to eq("Untitled presentation")
      expect(deck.duration).to eq("5 minutes")
      expect(deck.audience).to eq("general audience")
      expect(deck.goal).to eq("understand the key message")
      expect(deck.framework).to eq("slidev")
    end

    it "keeps provided values and downcases the framework" do
      deck = described_class.new(
        topic: "Observability",
        duration: "10 minutes",
        audience: "SREs",
        goal: "adopt the checklist",
        framework: "MARP"
      )

      expect(deck.topic).to eq("Observability")
      expect(deck.duration).to eq("10 minutes")
      expect(deck.audience).to eq("SREs")
      expect(deck.goal).to eq("adopt the checklist")
      expect(deck.framework).to eq("marp")
    end
  end

  describe "#slides" do
    it "builds five slides that reference the deck details" do
      deck = described_class.new(topic: "PDF Difference Monitoring", duration: "5 minutes", audience: "developers",
                                 goal: "try the MVP")

      slides = deck.slides

      expect(slides.size).to eq(5)
      expect(slides.first.title).to eq("PDF Difference Monitoring")
      expect(slides.first.bullets).to include("For developers", "Goal: try the MVP", "Length: 5 minutes")
      expect(slides.map(&:title)).to eq([
                                          "PDF Difference Monitoring",
                                          "Why this matters",
                                          "Core message",
                                          "Suggested narrative",
                                          "Next steps"
                                        ])
    end
  end
end

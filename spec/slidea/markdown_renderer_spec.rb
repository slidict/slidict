# frozen_string_literal: true

RSpec.describe Slidea::MarkdownRenderer do
  let(:deck) do
    Slidea::Deck.new(
      topic: "PDF Difference Monitoring Service",
      duration: "5 minutes",
      audience: "developers",
      goal: "try the MVP"
    )
  end

  describe "#render" do
    it "renders a slidev frontmatter by default" do
      markdown = described_class.new.render(deck)

      expect(markdown).to start_with("---\ntheme: default\nclass: text-center\ngenerated:")
    end

    it "renders the slide titles and bullets as markdown" do
      markdown = described_class.new.render(deck)

      expect(markdown).to include("# PDF Difference Monitoring Service")
      expect(markdown).to include("- For developers")
      expect(markdown).to include("- Goal: try the MVP")
    end

    it "separates slides with a horizontal rule" do
      markdown = described_class.new.render(deck)
      body = markdown.sub(/\A---.*?---\n/m, "")

      expect(body.scan("\n---\n\n").size).to eq(deck.slides.size - 1)
    end

    it "renders framework-specific frontmatter" do
      marp_deck = Slidea::Deck.new(topic: "x", duration: "x", audience: "x", goal: "x", framework: "marp")

      markdown = described_class.new.render(marp_deck)

      expect(markdown).to include("marp: true\ntheme: default")
    end

    it "falls back to the slidev frontmatter for unknown frameworks" do
      unknown_deck = Slidea::Deck.new(topic: "x", duration: "x", audience: "x", goal: "x", framework: "keynote")

      markdown = described_class.new.render(unknown_deck)

      expect(markdown).to include("theme: default\nclass: text-center")
    end
  end
end

# frozen_string_literal: true

module Slidict
  # Framework-independent application API for integrations such as slidict.io.
  # It turns source prose into both a Deck and presentation source without
  # involving CLI input/output or the filesystem.
  class Generator
    Result = Struct.new(:deck, :content, keyword_init: true)

    def initialize(client:, renderer: Output::Renderer.new)
      @client = client
      @renderer = renderer
    end

    def generate(text:, topic: nil, duration: nil, audience: nil, goal: nil,
                 framework: "slidev", language: nil, presentation_method: nil)
      source = text.to_s.strip
      raise ArgumentError, "text must not be empty" if source.empty?

      deck = Deck.new(
        topic: topic || title_from(source),
        duration: duration,
        audience: audience,
        goal: goal || "communicate the source text clearly",
        framework: framework,
        presentation_method: presentation_method,
        source: source
      )
      slides = @client.generate_slides(deck, language: language)
      generated_deck = Deck.new(
        topic: deck.topic, duration: deck.duration, audience: deck.audience, goal: deck.goal,
        framework: deck.framework, slides: slides, presentation_method: deck.presentation_method,
        source: source
      )

      Result.new(deck: generated_deck, content: @renderer.render(generated_deck))
    end

    private

    def title_from(source)
      source.each_line.map(&:strip).find { |line| !line.empty? }&.sub(/\A#+\s*/, "")
    end
  end
end

# frozen_string_literal: true

module Slidea
  Slide = Struct.new(:title, :bullets, keyword_init: true)

  class Deck
    attr_reader :topic, :duration, :audience, :goal, :framework

    def initialize(topic:, duration:, audience:, goal:, framework: "slidev", slides: nil)
      @topic = normalize(topic, fallback: "Untitled presentation")
      @duration = normalize(duration, fallback: "5 minutes")
      @audience = normalize(audience, fallback: "general audience")
      @goal = normalize(goal, fallback: "understand the key message")
      @framework = normalize(framework, fallback: "slidev").downcase
      @slides = slides
    end

    def slides
      @slides || default_slides
    end

    private

    def default_slides
      [
        Slide.new(title: topic, bullets: ["For #{audience}", "Goal: #{goal}", "Length: #{duration}"]),
        Slide.new(title: "Why this matters", bullets: ["Clarifies the problem before discussing solutions", "Keeps the story focused on audience value", "Sets up a memorable takeaway"]),
        Slide.new(title: "Core message", bullets: ["#{topic} should be easy to explain", "Every slide should support: #{goal}", "Details are included only when they help the audience decide or act"]),
        Slide.new(title: "Suggested narrative", bullets: ["Start with the current pain or opportunity", "Show what changes when #{topic} works well", "Close with the next step you want the audience to take"]),
        Slide.new(title: "Next steps", bullets: ["Review the generated outline", "Replace generic bullets with concrete examples", "Rehearse and refine for #{duration}"])
      ]
    end

    def normalize(value, fallback:)
      text = value.to_s.strip
      text.empty? ? fallback : text
    end
  end
end

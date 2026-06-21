# frozen_string_literal: true

module Slidea
  class MarkdownRenderer
    FRONTMATTER_BY_FRAMEWORK = {
      "slidev" => "theme: default\nclass: text-center",
      "marp" => "marp: true\ntheme: default",
      "asciidoctor-revealjs" => "revealjs_theme: white"
    }.freeze

    def render(deck)
      [frontmatter(deck.framework), deck.slides.map { |slide| render_slide(slide) }.join("\n---\n\n")].join("\n")
    end

    private

    def frontmatter(framework)
      body = FRONTMATTER_BY_FRAMEWORK.fetch(framework, FRONTMATTER_BY_FRAMEWORK["slidev"])
      "---\n#{body}\ngenerated: #{Time.now.utc.iso8601}\n---\n"
    end

    def render_slide(slide)
      lines = ["# #{slide.title}", ""]
      lines.concat(slide.bullets.map { |bullet| "- #{bullet}" })
      lines.join("\n")
    end
  end
end

# frozen_string_literal: true

module Slidict
  class MarkdownRenderer
    FRONTMATTER_BY_FRAMEWORK = {
      "slidev" => "theme: default\nclass: text-center",
      "marp" => "marp: true\ntheme: default"
    }.freeze

    def render(deck)
      return render_asciidoctor_revealjs(deck) if deck.framework == "asciidoctor-revealjs"

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

    def render_asciidoctor_revealjs(deck)
      lines = ["= #{deck.topic}", ":revealjs_theme: white", ":slidict_generated: #{Time.now.utc.iso8601}", ""]
      lines.concat(deck.slides.flat_map { |slide| render_asciidoctor_slide(slide) })
      lines.join("\n")
    end

    def render_asciidoctor_slide(slide)
      ["== #{slide.title}", "", *slide.bullets.map { |bullet| "* #{bullet}" }, ""]
    end
  end
end

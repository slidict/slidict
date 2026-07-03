# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Slidict
  module Llm
    # Talks to any OpenAI Compatible API (OpenAI, Ollama, LM Studio, vLLM, etc.)
    # via the standard /chat/completions endpoint. Configure the target with
    # Slidict::Config (base_url, api_key, model).
    class Client
      class Error < StandardError; end

      def initialize(base_url:, api_key:, model:)
        @base_url = base_url
        @api_key = api_key
        @model = model
      end

      # Checks that the endpoint is reachable before the (slower, more
      # expensive) chat completion request is made. Raises Error on failure.
      def verify_connection!
        response = get_models_response
        raise Error, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
      end

      # Returns a sorted array of model IDs available at the endpoint.
      def list_models
        response = get_models_response
        raise Error, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

        Array(JSON.parse(response.body)["data"]).map { |m| m["id"] }.sort
      rescue JSON::ParserError => e
        raise Error, "could not parse models response: #{e.message}"
      end

      def generate_slides(deck, language: nil)
        content = chat_completion(prompt_for(deck, language: language))
        slides_from(content)
      end

      # slide_texts is an array of slide bodies (1-indexed by position) as
      # produced by Slidict::Lint::SlideParser. Returns an array of
      # Slidict::Lint::Finding.
      def lint_slides(slide_texts, translate: nil)
        content = chat_completion(lint_prompt_for(slide_texts, translate: translate))
        findings_from(content)
      end

      # Translates a single line of text into language. Unlike
      # generate_slides/lint_slides, the response is a plain string rather
      # than parsed JSON: asking a (often small, local) model to translate
      # one line is a task it can follow reliably, whereas asking it to also
      # return a JSON array of a specific length is exactly the kind of
      # structured-output instruction weaker models tend to get wrong.
      def translate_text(text, language)
        strip_quotes(chat_completion(translate_prompt_for(text, language)).strip)
      end

      private

      def get_models_response
        uri = endpoint_uri("models")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        perform_request(uri, request)
      end

      def prompt_for(deck, language: nil)
        <<~PROMPT
          You are an assistant that designs presentation slide outlines.
          Topic: #{deck.topic}
          Duration: #{deck.duration}
          Audience: #{deck.audience}
          Goal: #{deck.goal}
          #{method_prompt_for(deck)}

          Return one slide for each required slide role when a presentation method is
          provided; otherwise return exactly 5 slides. Each item must be an object with
          a "title" string and a "bullets" array of 2-4 short strings.
          #{language_instruction_for(language)}Respond with the JSON array only: no commentary, no markdown code
          fences, and no reasoning or thinking content before or after it.
        PROMPT
      end

      def language_instruction_for(language)
        return "" unless language

        "Write the \"title\" and \"bullets\" text in #{language}.\n"
      end

      def method_prompt_for(deck)
        method = deck.presentation_method
        return "" unless method

        slides = method.slides.each_with_index.map do |slide, index|
          "#{index + 1}. #{slide.title} — role: #{slide.role}; instructions: #{slide.instructions}"
        end.join("\n")
        instructions = method.ai_instructions.map { |item| "- #{item}" }.join("\n")
        <<~METHOD
          Presentation method: #{method.name} (#{method.id})
          Method description: #{method.description}
          Required slide roles:
          #{slides}
          Method-specific generation instructions:
          #{instructions}
        METHOD
      end

      LINT_PROMPT_TEMPLATE = <<~PROMPT
        You are a presentation structure linter for tech talks and lightning talks.
        Your goal is not to judge how the slides look, but to diagnose whether the
        structure will actually land with an audience.

        Evaluate the deck as a whole against these six checks:

        1. Is the audience clear (who is this talk for)?
        2. Can the overall point be stated in one sentence?
        3. Does the deck flow background -> problem -> solution -> result/learning
           (call out where the flow breaks down)?
        4. Is any single slide overloaded with information?
        5. Is jargon used without first explaining it?
        6. Does the closing slide give the audience one concrete takeaway?

        For each finding, name the single slide it relates to most. For deck-wide
        findings (unclear audience, unclear thesis, etc.), point to the slide where
        the problem is most visible, or slide 1 if you cannot tell.

        Decide severity using these rules:
        - warning: likely to block audience understanding (checks 1-5)
        - info: a suggestion that would make things better (check 6, or minor polish)

        Here is the slide content ("--- Slide N ---" marks each slide boundary):

        %<numbered>s

        Respond with a JSON array of findings only. Each item must be an object of
        the form {"slide": <integer>, "severity": "warning" or "info", "message": "<one sentence>"}.

        Do not include any commentary, markdown code fences, or text other than the
        JSON array. Return an empty array [] if you find no issues.
      PROMPT

      def lint_prompt_for(slide_texts, translate: nil)
        numbered = slide_texts.each_with_index.map { |text, i| "--- Slide #{i + 1} ---\n#{text}" }.join("\n\n")
        prompt = format(LINT_PROMPT_TEMPLATE, numbered: numbered)
        translate ? "#{prompt}\nTranslate only the \"message\" field of each finding into #{translate}. Keep \"slide\" as an integer and \"severity\" as exactly \"warning\" or \"info\" — do not translate those values." : prompt
      end

      def translate_prompt_for(text, language)
        <<~PROMPT
          Translate the following text into #{language}. Respond with only the
          translation: no commentary, no surrounding quotation marks, no
          markdown formatting, and no reasoning or thinking content before or
          after it.

          #{text}
        PROMPT
      end

      # Small/local models often ignore the "no quotation marks" instruction
      # above and wrap the translation anyway.
      def strip_quotes(text)
        text.sub(/\A["'“”‘’「」]+/, "").sub(/["'“”‘’「」]+\z/, "")
      end

      def findings_from(content)
        parsed = JSON.parse(extract_json_array(content))
        raise Error, "expected a JSON array of findings" unless parsed.is_a?(Array)

        parsed.map { |item| finding_from(item) }
      rescue JSON::ParserError, KeyError, ArgumentError, TypeError => e
        raise Error, "could not parse model response: #{e.message}"
      end

      def finding_from(item)
        Lint::Finding.new(
          slide: Integer(item.fetch("slide")),
          severity: normalize_severity(item["severity"]),
          message: item.fetch("message")
        )
      end

      def normalize_severity(value)
        %w[warning info].include?(value) ? value : "info"
      end

      def chat_completion(prompt)
        response = JSON.parse(post_chat_completion(prompt))
        content = response.dig("choices", 0, "message", "content")
        raise Error, "empty response from model" if content.to_s.strip.empty?

        content
      rescue JSON::ParserError => e
        raise Error, "could not parse model response: #{e.message}"
      end

      def post_chat_completion(prompt)
        uri = endpoint_uri("chat/completions")
        request = build_request(uri, prompt)
        response = perform_request(uri, request)

        raise Error, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def perform_request(uri, request)
        Net::HTTP.start(uri.host, uri.port,
                        use_ssl: uri.scheme == "https",
                        open_timeout: 5,
                        read_timeout: 30,
                        write_timeout: 30) do |http|
          http.request(request)
        end
      rescue StandardError => e
        raise Error, e.message
      end

      def endpoint_uri(path)
        base = @base_url.to_s.sub(%r{/+\z}, "")
        URI.join("#{base}/", path)
      end

      def build_request(uri, prompt)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@api_key}"
        request.body = JSON.generate(
          model: @model,
          messages: [{ role: "user", content: prompt }],
          temperature: 0.7
        )
        request
      end

      def slides_from(content)
        parsed = JSON.parse(extract_json_array(content))
        raise Error, "expected a JSON array of slides" unless parsed.is_a?(Array)

        parsed.map do |item|
          Slide.new(title: item.fetch("title"), bullets: Array(item.fetch("bullets")))
        end
      rescue JSON::ParserError, KeyError => e
        raise Error, "could not parse model response: #{e.message}"
      end

      # Some models (especially reasoning models served through LM Studio or
      # Ollama) prepend or append thinking/reasoning text around the JSON
      # answer instead of returning it verbatim, so the array is extracted from
      # within the raw content rather than parsed as-is.
      def extract_json_array(content)
        content.enum_for(:scan, /\[/).each do
          start = Regexp.last_match.begin(0)
          candidate = json_array_from(content, start)
          return candidate if candidate
        end

        raise Error, "no JSON array found in model response\nThe model may be too small to follow the required output format. Try using a larger model."
      end

      def json_array_from(content, start)
        finish = start
        while (finish = content.index("]", finish))
          candidate = content[start..finish]
          return candidate if parses_to_array?(candidate)

          finish += 1
        end
        nil
      end

      def parses_to_array?(candidate)
        JSON.parse(candidate).is_a?(Array)
      rescue JSON::ParserError
        false
      end
    end
  end
end

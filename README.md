# Slidea

Generate presentation-ready slides from a simple conversation.

Slidea is a CLI tool that helps you turn rough ideas into presentations through AI-guided conversations.

Unlike traditional slide generators, Slidea focuses on communication before slide creation.

## Features

- Interactive CLI conversation
- Generate Markdown slides for Slidev, Marp, Asciidoctor Reveal.js, and other OSS presentation frameworks
- Local-first MVP implemented in Ruby
- OpenAI Compatible API support, so you can point Slidea at OpenAI, Ollama, LM Studio, vLLM, or any other server implementing the same `/chat/completions` endpoint

## Requirements

- Ruby 3.1 or later

## Usage

Run the executable directly from this repository:

```bash
bin/slidea
```

Slidea asks a few questions and writes `slides.md`:

```bash
$ bin/slidea

What would you like to talk about?
> PDF Difference Monitoring Service
How long is the presentation?
> 5 minutes
Who is the audience?
> Engineering managers
What should the audience remember or do?
> Approve an MVP pilot
Created slides.md
```

You can also provide answers non-interactively:

```bash
bin/slidea \
  --topic "PDF Difference Monitoring Service" \
  --duration "5 minutes" \
  --audience "Engineering managers" \
  --goal "Approve an MVP pilot" \
  --framework slidev \
  --output slides.md
```

Output:

```text
slides.md
```

## Configuration

Slidea generates slides with an LLM through any OpenAI Compatible API. Configure the
target endpoint with environment variables or CLI flags (flags take precedence):

| Environment variable    | CLI flag         | Default        |
| ------------------------ | ---------------- | -------------- |
| `SLIDEA_LLM_BASE_URL`    | `--llm-base-url` | _(none)_       |
| `SLIDEA_LLM_API_KEY`     | `--llm-api-key`  | _(none)_       |
| `SLIDEA_LLM_MODEL`       | `--llm-model`    | `gpt-4o-mini`  |

If no `llm-base-url` is configured, Slidea uses its built-in slide template and never
calls an LLM. Once a `llm-base-url` is set, Slidea always calls that endpoint; if the
request fails, Slidea reports the error and exits without writing a file (no fallback).
You can force the template even when a base URL is configured with `--no-llm`.

Examples:

```bash
# OpenAI
export SLIDEA_LLM_BASE_URL=https://api.openai.com/v1
export SLIDEA_LLM_API_KEY=sk-...
bin/slidea --topic "PDF Difference Monitoring Service" --duration "5 minutes" \
  --audience "Engineering managers" --goal "Approve an MVP pilot"

# Ollama (running locally, OpenAI Compatible API)
bin/slidea --llm-base-url http://localhost:11434/v1 --llm-api-key ollama --llm-model llama3

# LM Studio (running locally, OpenAI Compatible API)
bin/slidea --llm-base-url http://localhost:1234/v1 --llm-api-key lm-studio --llm-model local-model
```

## Philosophy

Slidea helps you communicate ideas, not just create slides.

Many presentation tools focus on layouts, themes, and visual design.

Slidea focuses on the message.

Before generating slides, Slidea helps you:

- Clarify your message
- Build a compelling narrative
- Focus on what matters
- Create presentations people remember

```text
Idea
 ↓
Conversation
 ↓
Story
 ↓
Slides
```

We optimize for communication, not decoration.

## Roadmap

- [x] Interactive CLI
- [x] Slide generation
- [x] OpenAI Compatible API support (configurable base URL, so Ollama, LM Studio, and other compatible servers work out of the box)

## License

MIT

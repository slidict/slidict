# Slidict

Generate presentation source files from a simple conversation.

Slidict is a CLI tool that helps you turn rough ideas into presentations through AI-guided conversations.

Unlike traditional slide generators, Slidict focuses on communication before slide creation.

## Features

- Interactive CLI conversation
- Generate slides for Slidev, Marp, Asciidoctor Reveal.js, and other OSS presentation frameworks
- Local-first MVP implemented in Ruby
- OpenAI Compatible API support, so you can point Slidict at OpenAI, Ollama, LM Studio, vLLM, or any other server implementing the same `/chat/completions` endpoint

## Requirements

- Ruby 3.1 or later

## Usage

Run the executable directly from this repository:

```bash
bin/slidict
```

Slidict asks a few questions and generates presentation source files. For example, this creates a Marp Markdown deck:

```bash
$ bin/slidict --framework marp --output slides.md

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
bin/slidict \
  --topic "PDF Difference Monitoring Service" \
  --duration "5 minutes" \
  --audience "Engineering managers" \
  --goal "Approve an MVP pilot" \
  --framework asciidoctor-revealjs \
  --output slides.adoc
```

## Output files

Choose the framework and output path that match the presentation tool you want to use. If you omit `--output`, Slidict chooses a framework-specific default:

```text
Slidev                  -> slides.md
Marp                    -> slides.md
Asciidoctor Reveal.js   -> slides.adoc
```

## Configuration

Slidict generates slides with an LLM through any OpenAI Compatible API. Configure the
target endpoint with environment variables or CLI flags (flags take precedence):

| Environment variable    | CLI flag         | Default        |
| ------------------------ | ---------------- | -------------- |
| `SLIDICT_LLM_BASE_URL`    | `--llm-base-url` | _(none)_       |
| `SLIDICT_LLM_API_KEY`     | `--llm-api-key`  | _(none)_       |
| `SLIDICT_LLM_MODEL`       | `--llm-model`    | `gpt-4o-mini`  |

If no `llm-base-url` is configured, Slidict uses its built-in slide template and never
calls an LLM. Once a `llm-base-url` is set, Slidict always calls that endpoint; if the
request fails, Slidict reports the error and exits without writing a file (no fallback).
You can force the template even when a base URL is configured with `--no-llm`.

Examples:

```bash
# OpenAI
export SLIDICT_LLM_BASE_URL=https://api.openai.com/v1
export SLIDICT_LLM_API_KEY=sk-...
bin/slidict --topic "PDF Difference Monitoring Service" --duration "5 minutes" \
  --audience "Engineering managers" --goal "Approve an MVP pilot"

# Ollama (running locally, OpenAI Compatible API)
bin/slidict --llm-base-url http://localhost:11434/v1 --llm-api-key ollama --llm-model llama3

# LM Studio (running locally, OpenAI Compatible API)
bin/slidict --llm-base-url http://localhost:1234/v1 --llm-api-key lm-studio --llm-model local-model
```

## Philosophy

Slidict helps you communicate ideas, not just create slides.

Many presentation tools focus on layouts, themes, and visual design.

Slidict focuses on the message.

Before generating slides, Slidict helps you:

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

# Slidict

Generate presentation source files from a simple conversation.

Slidict is a CLI tool that helps you turn rough ideas into presentations through AI-guided conversations.

Unlike traditional slide generators, Slidict focuses on communication before slide creation.

## Demo

![Slidict conversation-to-slides demo](docs/demo.gif)

![Slidict presentation methods demo](docs/demo-methods.gif)

[Read the walkthrough slides on slidict.io](https://slidict.io/slides/140)

## Features

- Interactive CLI conversation
- Generate slides for Slidev, Marp, Asciidoctor Reveal.js, and other OSS presentation frameworks
- Local-first MVP implemented in Ruby
- Built-in Sinatra server for browsing generated slides from `public/`
- OpenAI Compatible API support, so you can point Slidict at OpenAI, Ollama, LM Studio, vLLM, or any other server implementing the same `/chat/completions` endpoint
- Presentation structure linter: checks whether a Markdown/Asciidoc deck's *structure* (not its looks) will land with an audience

## Requirements

- Ruby 3.2.0 or later

## Usage

Run the executable directly from this repository:

```bash
bin/slidict
```

Slidict asks a few questions and generates presentation source files. For example, this creates a Marp Markdown deck:

```bash
$ bin/slidict --framework marp

What would you like to talk about?
> PDF Difference Monitoring Service
How long is the presentation?
> 5 minutes
Who is the audience?
> Engineering managers
What should the audience remember or do?
> Approve an MVP pilot
Created public/001.md
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

To create a presentation from an existing article, memo, or other prose, pass the
text directly or read it from a file. Source-text generation requires an LLM endpoint;
the first non-empty line is used as the topic when `--topic` is omitted. Slidict asks
the model to preserve the source's facts and examples instead of inventing claims.

```bash
bin/slidict --text-file proposal.md \
  --llm-base-url https://api.openai.com/v1 \
  --llm-api-key "$OPENAI_API_KEY" --llm-model gpt-4o-mini

bin/slidict --text "Why our team should adopt automated accessibility testing ..." \
  --llm-base-url http://localhost:11434/v1 --llm-api-key ollama --llm-model llama3
```

Applications can use the same pipeline without CLI or filesystem side effects. The
result contains both the structured `deck` and rendered presentation `content`:

```ruby
client = Slidict::Llm::Client.new(base_url: url, api_key: key, model: model)
result = Slidict::Generator.new(client: client).generate(
  text: article,
  framework: "slidev",
  language: "Japanese"
)
result.deck    # => Slidict::Deck
result.content # => Slidev source
```

Add `--publish` to also save the generated slides to slidict.io as a draft (requires
`slidict auth` first). Pass `--slide-id` to edit an existing draft instead of creating a
new one:

```bash
# Create a new draft on slidict.io from the generated slides
bin/slidict --topic "PDF Difference Monitoring Service" --duration "5 minutes" \
  --audience "Engineering managers" --goal "Approve an MVP pilot" --publish

# Edit an existing draft (slide #42) instead of creating a new one
bin/slidict --topic "PDF Difference Monitoring Service" --duration "5 minutes" \
  --audience "Engineering managers" --goal "Approve an MVP pilot" --slide-id 42
```

## Output files

Choose the framework and output path that match the presentation tool you want to use. If you omit `--output`, Slidict writes under `public/` with the next sequential file name. Use `--filename` to choose the relative file name under `public/`; Slidict appends the framework extension when the name has no extension.

```bash
# Choose a served file name under public/
bin/slidict --filename product-demo/slides --topic "Product Demo"
```

```text
Slidev                  -> public/001.md, public/002.md, ...
Marp                    -> public/001.md, public/002.md, ...
Asciidoctor Reveal.js   -> public/001.adoc, public/002.adoc, ...
```

## Commands

### `slidict init`

Creates a `.env` file for `SLIDICT_LLM_*`, `SLIDICT_FRAMEWORK`, and `SLIDICT_METHOD`
(see [Configuration](#configuration)) and adds `.env` to `.gitignore`. Does nothing to
an existing `.env` or an already-updated `.gitignore`.

```bash
bin/slidict init
```

### `slidict auth`

Authenticates the CLI with your GitHub account via the device code flow and saves a
CLI access token to `~/.config/slidict/credentials.json`.

```bash
bin/slidict auth
```

### `slidict slides`

Manage your slides on slidict.io using the CLI access token saved by `slidict auth`.

```bash
bin/slidict slides list [--page N]
bin/slidict slides show <id>
bin/slidict slides create [--title TEXT] [--body TEXT | --file PATH] [--body-format asciidoc|markdown] [--visibility public|unlisted|group_only]
bin/slidict slides edit <id> [--title TEXT] [--body TEXT | --file PATH] [--body-format asciidoc|markdown] [--visibility public|unlisted|group_only]
```

- `create` and `edit` always save the slide as a draft. Publishing requires going through
  the moderation flow on the Web UI; the CLI cannot publish a slide.
- `edit` only works on slides that are still drafts; editing an already-published slide
  must be done from the Web UI.
- `create`/`edit` are rate limited to once per minute per user.

Run `bin/slidict slides -h` for the full list of options.

### `slidict serve`

Serve generated slide files from the local `public/` directory with Sinatra. The top
page lists Markdown and Asciidoc slide files below `public/`, so you can organize
decks in subdirectories such as `public/product-demo/slides.md`. Any arguments
after `serve` are passed through to Sinatra.

```bash
bin/slidict serve -p 4567 -o 0.0.0.0
```

`bin/slidict --publish` and `--slide-id` (see [Usage](#usage)) wrap this same `create`/`edit`
behavior so you can save the slides you just generated straight to slidict.io.

### `slidict lint`

Diagnoses whether a Markdown or Asciidoc slide deck has a structure an audience can
actually follow -- not whether it looks nice. Diagnosis only; it does not rewrite the
file. Requires an LLM endpoint (see [Configuration](#configuration)).

```bash
bin/slidict lint talk.md --llm-base-url http://localhost:11434/v1 --llm-api-key ollama --llm-model llama3
```

```text
[warning] Slide 3: this slide's main point is unclear
[warning] Slide 5: "MCP" is used without first explaining it
[info] Slide 8: the closing slide is weak; consider adding a one-sentence takeaway for the audience
```

It checks six things across the whole deck:

1. Is the audience clear?
2. Can the overall point be stated in one sentence?
3. Does the deck flow background → problem → solution → result/learning?
4. Is any single slide overloaded with information?
5. Is jargon used without first explaining it?
6. Does the closing slide give the audience a concrete takeaway?

The deck format (`markdown` or `asciidoc`) is auto-detected from the file extension;
override it with `--format`. Run `bin/slidict lint -h` for the full list of options.

## Configuration

Slidict generates slides with an LLM through any OpenAI Compatible API. Configure the
target endpoint with environment variables, a `.env` file, or CLI flags:

| Environment variable    | CLI flag         | Default        |
| ------------------------ | ---------------- | -------------- |
| `SLIDICT_LLM_BASE_URL`    | `--llm-base-url` | _(none)_       |
| `SLIDICT_LLM_API_KEY`     | `--llm-api-key`  | _(none)_       |
| `SLIDICT_LLM_MODEL`       | `--llm-model`    | `gpt-4o-mini`  |
| `SLIDICT_FRAMEWORK`       | `--framework`    | `slidev`       |
| `SLIDICT_METHOD`          | `--method`       | _(none)_       |

Precedence is CLI flag > real environment variable > `.env` file > built-in default (a
`.env` value fills in only variables that aren't already set in the environment). Run
`slidict init` to create a `.env` file in the current directory (with these variables
commented out) and add `.env` to `.gitignore`:

```bash
bin/slidict init
```

```text
Created .env
Added .env to .gitignore
```

Then edit `.env` to set the values you want, for example:

```bash
SLIDICT_LLM_BASE_URL=http://localhost:11434/v1
SLIDICT_LLM_API_KEY=ollama
SLIDICT_LLM_MODEL=llama3
SLIDICT_FRAMEWORK=marp
```

Since `.env` is gitignored, it's a good place for secrets like API keys that
shouldn't be committed. A CLI flag always overrides both `.env` and the real
environment for that invocation.

If no `llm-base-url` is configured, Slidict uses its built-in slide template and never
calls an LLM. Once a `llm-base-url` is set, Slidict always calls that endpoint; if the
request fails, Slidict reports the error and exits without writing a file (no fallback).
You can force the template even when a base URL is configured with `--no-llm`.

Use `--language LANG` (e.g. `--language Japanese`) to have the LLM write the generated
slide titles and bullets in a language other than English. When an `llm-base-url` is
also configured, Slidict asks the LLM to translate any interactive questions it still
needs to ask (topic, duration, audience, goal) into that language too, so you're not
answering Japanese-bound slides in English prompts. This only affects LLM-generated
slides and questions; the built-in template stays in English.

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

## Presentation methods

Use `--method` to generate slides with a specific narrative structure. Built-in methods include SDS, PREP, DESC,
AIDMA, TAPS, FABE, SCQA, and Pyramid Principle.

```bash
bin/slidict --method scqa --topic "Database migration plan"
bin/slidict --method aidma --topic "Product launch"
bin/slidict list-methods
bin/slidict show-method scqa
```

See [Presentation methods](docs/presentation-methods.md) for the YAML schema, plugin layout, and contribution workflow.

## Project resources

- [Presentation method guide](docs/presentation-methods.md)
- [Changelog](CHANGELOG.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [License](LICENSE)

## Roadmap

- [x] Interactive CLI
- [x] Slide generation
- [x] OpenAI Compatible API support (configurable base URL, so Ollama, LM Studio, and other compatible servers work out of the box)
- [x] Presentation structure linter (`slidict lint`)

## License

MIT

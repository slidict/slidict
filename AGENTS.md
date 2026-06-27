# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

Slidict is a Ruby CLI gem that turns conversational input into presentation
source files (Slidev, Marp, Asciidoctor Reveal.js, etc.) via an
OpenAI-compatible chat API.

## Setup

- Ruby 3.1+
- Install dependencies: `bundle install`

## Development workflow

- Run tests: `bundle exec rspec`
- Run lint: `bundle exec rubocop`
- Run the CLI locally: `bin/slidict`

Run both tests and lint before considering a change complete.

When you add or change a CLI command (or its options), update the "Commands" section
of `README.md` to document it.

## Commit conventions

Use Conventional Commits for every commit message: `<type>: <summary>`.

Common types used in this repo:

- `feat:` new functionality
- `fix:` bug fixes
- `chore:` maintenance, version bumps, dependency updates
- `ci:` CI/workflow changes
- `docs:` documentation only changes
- `refactor:` code change that neither fixes a bug nor adds a feature
- `test:` adding or correcting tests

Keep the summary short and in the imperative mood (e.g. `fix: handle empty topic input`).

# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

Slidict is a Ruby CLI gem that turns conversational input into presentation
source files (Slidev, Marp, Asciidoctor Reveal.js, etc.) via an
OpenAI-compatible chat API.

## Setup

- Ruby 3.2.0+
- Install dependencies: `bundle install`

## Development workflow

- Run tests: `bundle exec rspec`
- Run lint: `bundle exec rubocop`
- Run the CLI locally: `bin/slidict`

Run both tests and lint before considering a change complete.

When you add or change a feature (a CLI command, its options, or any other
user-facing behavior), update `README.md` to document it.

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

## Versioning (SemVer)

This project follows [Semantic Versioning](https://semver.org/). For a CLI like slidict, apply these rules:

| Change type | Version bump |
|---|---|
| Breaking change — existing commands, options, config format, or output parsing breaks | `MAJOR` (`1.x → 2.0.0`) |
| Backward-compatible addition — new command, new option, new output field | `MINOR` (`1.2.x → 1.3.0`) |
| Backward-compatible fix — bug fix, internal refactor, perf improvement, dependency update | `PATCH` (`1.2.3 → 1.2.4`) |

While the project is at `0.x`, breaking changes may be released as `MINOR` bumps (e.g. `0.3.x → 0.4.0`) following common OSS convention.

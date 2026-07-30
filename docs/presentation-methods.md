# Presentation methods

Slidict supports data-driven presentation methods. A method defines the narrative
technique, slide roles, AI instructions, and review checklist in YAML, while the Ruby
gem only loads, validates, and applies that data.

## Using methods

```bash
bin/slidict new --method prep --topic "New onboarding flow"
bin/slidict --method scqa --topic "Database migration plan"
bin/slidict --method pyramid --topic "FY roadmap recommendation"
bin/slidict --method fabe --topic "Customer analytics platform"
bin/slidict list-methods
bin/slidict show-method scqa
```

Built-in methods currently include SDS, PREP, DESC, AIDMA, TAPS, FABE, SCQA,
and Pyramid Principle.

## Architecture

The method system is intentionally data-first:

1. YAML files live in `data/slidict/methods/`.
2. `Slidict::PresentationMethodRegistry` discovers built-in files and plugin-provided files.
3. `Slidict::PresentationMethod` validates each YAML document and maps it to Ruby objects.
4. `Slidict::Deck` uses the method's slide roles as the built-in non-LLM outline.
5. `Slidict::Llm::Client` injects the method description, slide roles, and AI instructions into the generation prompt.

This keeps contribution review small: a new built-in method is usually one YAML file and no Ruby code.

## Directory structure

```text
data/slidict/methods/
  aidma.yml
  desc.yml
  fabe.yml
  prep.yml
  pyramid.yml
  scqa.yml
  sds.yml
  taps.yml
lib/slidict/presentation_method.rb
```

For 100+ methods, keep one method per file and use stable lowercase IDs such as
`scqa`, `prep`, `pyramid`, or `problem-solution`. Categories are free-form labels
that can later drive filtering without changing the file layout.

## YAML schema

Each method file is a single YAML mapping:

```yaml
id: scqa
name: SCQA
category: narrative
description: Situation, Complication, Question, Answer structure for building a clear business narrative.
locale: en
suitable_for:
  - Strategy updates
  - Problem-solving proposals
slides:
  - title: Situation
    role: Establish the shared context the audience already recognizes.
    instructions: Describe the current state with concrete facts.
ai_instructions:
  - Use the SCQA sequence exactly.
review_checklist:
  - Does the situation establish common ground?
references:
  - title: The Pyramid Principle
    author: Barbara Minto
```

Required fields are `id`, `name`, `category`, `description`, `suitable_for`,
`slides`, `ai_instructions`, and `review_checklist`. `references` and `locale` are
optional; `locale` defaults to `en`. Every slide entry requires `title`, `role`, and
`instructions`.

## Ruby class design

- `Slidict::PresentationMethod` represents one method definition.
- `Slidict::MethodSlide` represents each slide role.
- `Slidict::PresentationMethodRegistry` loads built-in YAML files and plugin YAML files.
- `Slidict::Deck` accepts an optional `presentation_method` and turns method slide roles into a local template when `--no-llm` is used or no LLM is configured.

Validation happens at load time with `YAML.safe_load_file`. Slidict checks required
fields, requires lowercase method IDs (`a-z`, `0-9`, and `-`), and verifies that each
slide role has the required fields.

## CLI design

- `--method ID` applies a method to generated slides.
- `list-methods` prints every discovered method.
- `show-method ID` prints a method's description, use cases, slide roles, and review checklist.

## Plugin design

External gems can distribute methods without changing Slidict itself. A plugin gem only
needs to place YAML files under `lib/slidict/methods/*.yml` so RubyGems can expose them
through `Gem.find_files`.

Example plugin layout:

```text
slidict-methods-product/
  lib/slidict/methods/product-demo.yml
  slidict-methods-product.gemspec
```

After the plugin gem is installed, Slidict automatically includes those YAML files in
`list-methods`, `show-method`, and `--method` lookup.

## Future localization

Method files include a `locale` field. The recommended future shape is one file per
localized method, for example `scqa.en.yml` and `scqa.ja.yml`, with the same method ID
plus locale-aware lookup. Keeping all user-facing text in YAML means translations can be
reviewed independently from Ruby changes.

## OSS contribution workflow

To propose a new presentation method:

1. Copy an existing YAML file in `data/slidict/methods/`.
2. Change `id`, `name`, `category`, `description`, `suitable_for`, `slides`, `ai_instructions`, and `review_checklist`.
3. Add `references` when useful.
4. Run `bundle exec rspec` and `bundle exec rubocop`.
5. Open a PR with the method file and a short explanation of the communication technique.

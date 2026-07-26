## [Unreleased]

- Add source-text slide generation through `--text`, `--text-file`, and the reusable
  `Slidict::Generator` integration API.
- Add `slidict init` to create a `.env` file (for `SLIDICT_LLM_*`, `SLIDICT_FRAMEWORK`,
  and `SLIDICT_METHOD`) and add it to `.gitignore`. `.env` is loaded automatically and
  fills in unset environment variables; CLI flags still take precedence.
- Add `SLIDICT_FRAMEWORK` and `SLIDICT_METHOD` environment variables as defaults for
  `--framework` and `--method`.
- Add `--language` to generate slide titles and bullets in a language other than English,
  and to translate the interactive prompt questions into that language via the LLM.

## [0.5.0] - 2026-07-01

- Add data-driven presentation methods with SCQA, PREP, and Pyramid Principle templates.
- Add `--method`, `list-methods`, and `show-method` CLI support.


## [0.1.0] - 2026-06-21

- Initial release

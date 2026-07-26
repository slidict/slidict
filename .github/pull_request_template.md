## Summary

<!-- What does this PR change, and why? -->

## Version bump

This repository follows [Semantic Versioning](https://semver.org/) (see `AGENTS.md`).
Every PR is expected to update `lib/slidict/version.rb`, and CI fails when it does not.

- [ ] <!-- skip-version-check --> This PR does not require a version bump

<!--
Leave the box above unchecked and bump `lib/slidict/version.rb` in this PR.
Check it only when no release is needed (docs-only, CI-only, test-only changes, etc.).
Keep the `skip-version-check` comment intact — the CI check looks for it.
-->

## Checklist

- [ ] `bundle exec rspec` passes
- [ ] `bundle exec rubocop` passes
- [ ] `README.md` updated if user-facing behavior changed

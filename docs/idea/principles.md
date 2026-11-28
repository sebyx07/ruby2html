# Principles

The product's promises are the invariants in `CLAUDE.md` § Invariants and the "Design constraints"
section of [`docs/architecture.md`](../architecture.md). This page says why they exist, and does
not restate them.

- **Escaping is the product's safety promise.** A view layer that lets one unescaped value through
  is a cross-site scripting hole in every app that uses it, so text and attribute values are
  escaped unless the caller marked them `html_safe`, and names are validated, never escaped. An
  escaping change is reviewed as a security change (`SECURITY.md`, agent `xss-auditor`).
- **Two implementations, one behaviour.** A user cannot choose which renderer they get: a failed
  compile, JRuby or TruffleRuby silently selects the pure-Ruby one. If the two differed, the same
  template would render differently between a laptop and production. So output, encoding and
  raised errors are byte-identical, and a rule lands on both sides in one change
  (`spec/gem/render_parity_spec.rb`, `spec/gem/render_fuzz_spec.rb`).
- **No cache that can return someone else's output.** A cache keyed by `Object#hash` once rendered
  another element's attributes on a collision. Correct output outranks a faster wrong one.
- **Speed is measured, never claimed.** The C extension exists for speed, so a hot-path change
  carries before and after numbers, and the docs say only what the benchmark workflow measures:
  no hand-typed numbers or version lists (`.github/workflows/benchmark.yml`). The README charts
  are generated from one committed, dated run (`bin/bench-charts`, `docs/benchmarks/x86_64-linux.json`).
- **Light to adopt.** No runtime dependency, and `require 'ruby2html'` loads only the renderer:
  a view helper should not decide what else an app loads.
- **Rails behaves like Rails.** Helpers such as `form_with` delegate to Rails' own instead of
  re-implementing them, so a Rails upgrade or setting keeps working.
- **The public API is a contract.** Templates are application code that nobody re-reads on a gem
  update: a breaking change is the owner's decision and a major version (`lib/CLAUDE.md`).
- **Maintained by agents, gated by checks.** A rule that must hold is a check in `bin/check` or a
  CI job under `CI OK`, not a sentence someone must remember ([`standards`](../standards/README.md)).

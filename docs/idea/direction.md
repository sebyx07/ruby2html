# Direction

> **Draft for the owner to correct.** Written on 2026-11-23 from `README.md`, `CHANGELOG.md`
> (`## [Unreleased]`, 2.1.0 and 2.0.0) and the pull requests merged so far; nothing here was stated
> by the owner. Every line is a reading of what the project already does, not a new goal. Edit it
> in place, then remove this note. Until then, agents treat it as maintenance guidance only, and
> `scout.survey` stays at its default (`broken_only`) in `.dz/maintainer/maintainer.yml`.

## What the product is for

Writing HTML views in plain Ruby: every HTML5 tag is a method, control flow is Ruby's own, output
is escaped by default and compact. It is used standalone, as Rails `.html.rb` templates, inside
ERB, in ViewComponent and through `Ruby2html::Component`, and it can be adopted one view at a time
beside ERB and Slim (`README.md`). Readers: Rails developers, and AI coding tools that read
`llms.txt`.

## What "better" means here

Ranked as `CLAUDE.md` § Invariants and the merged work so far rank it. The order is a reading, and
is the first thing for the owner to correct.

1. **Output is safe.** Escaping by default is a security boundary, and a fix there outranks
   everything: the `Object#hash` attribute cache that could render another element's attributes
   was removed (2.0.0 "Fixed"), `html_safe` double escaping was fixed (2.0.0), and the buffer
   self-append read of freed memory was fixed (`## [Unreleased]` "Fixed"). `SECURITY.md` puts
   escaping bypasses and C memory safety in scope.
2. **The C extension and the pure-Ruby renderer are byte-identical.** 2.0.0 "Added" introduced the
   twin with identical output; `## [Unreleased]` adds a differential fuzz spec and fixes every
   divergence it found, error messages included.
3. **It runs wherever Ruby and Rails are maintained.** A generated CRuby and Rails matrix, JRuby
   and TruffleRuby (#4); a Java escaper for JRuby and pure Ruby on TruffleRuby (#10, 2.1.0); Rails
   main compatibility ahead of its release (#9); the Rails specs on the pure-Ruby renderer and on
   JRuby (`## [Unreleased]` "Changed").
4. **Rails behaves like Rails.** `form_with` and `link_to` delegate to Rails' own (2.0.0 "Fixed");
   strict locals, blocks given to `render` and fragment-cache digests follow ActionView
   (`## [Unreleased]` "Fixed"); `respond_to_missing?` claims only what it serves (#20).
5. **Fast, and honest about it.** 2.0.0 "Performance" is the rewrite for speed and allocations;
   benchmarks run in CI on every pull request (#4); a stale benchmark snapshot was removed from
   the docs (#27), and `## [Unreleased]` "Changed" corrects the claim of being faster than ERB to
   what CI measures.
6. **Light to adopt.** No runtime dependency, a cheap `require`, `htmlbeautifier` optional (2.0.0
   "Performance" and "Upgrading to 2.0", item 13).
7. **Maintained without hand work.** Every CI job required, a monthly canary and improvement pass
   (#7); the weekly judged release (#12); advisory audits of every resolved dependency set (#24);
   `bin/check` aligned with CI (#28); scheduled briefs with rows (#30).

## Out of bounds

The policy's `triage.non_goals` in `.dz/maintainer/maintainer.yml` is the list. It is linked here,
not copied. Breaking changes and major releases are the owner's (`escalate` in the same file).

## Open questions for the owner

- Is the ranking above right, in particular parity above reach and speed below Rails behaviour?
- Is the gem feature-complete and in maintenance, or are new DSL features wanted? Nothing merged
  since 2.1.0 adds one.
- Is rendering faster than Erubi a goal? `## [Unreleased]` records that Erubi is ahead on the
  standalone page render today.
- Should the Rails integration be tested on TruffleRuby, and on more than one Rails line on JRuby?
  Both are stated limits in `README.md` § Compatibility.
- When do the Ruby and Rails floors move, and does the 1.x template path for Rubies without Prism
  stay until then?

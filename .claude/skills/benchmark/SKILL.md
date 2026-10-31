---
name: benchmark
description: Measure ruby2html rendering performance and compare before/after a change (C extension, pure-Ruby twin, render.rb, template handler, components). Use when a change claims or may affect speed, or when the user asks to benchmark, profile or compare against ERB/Slim/Phlex/ViewComponent.
---

# Benchmark ruby2html (before/after)

Project rule: speed over memory. Perf claims need numbers from the same machine, Ruby and YJIT state.

## Tools

| Command | Measures |
|---|---|
| `bundle exec rake bench` | compiles, runs every `bench/*.rb` |
| `bundle exec ruby bench/render_bench.rb` | full page render vs Phlex / Erubi, plus allocations per render |
| `bundle exec ruby bench/tag_bench.rb` | per-tag cost for common call shapes |
| `bundle exec ruby bench/escape_bench.rb` | escaping throughput, clean/dirty, short/long |
| `bundle exec rspec spec/benchmarks/` | request-level through the demo app: ERB, Slim, `.html.rb`, ViewComponent, Phlex (10 s warmup + 60 s each, ~6 min; skipped when `CI` is set) |

Variants: `--yjit` (or `RUBY_YJIT_ENABLE=1`), `RUBY2HTML_DISABLE_EXT=1` (pure Ruby), `BENCH_TIME=5` (seconds per ips run, render_bench), `RUBY2HTML_NO_SIMD=1 bundle exec rake compile` (scalar escape path; recompile normally afterwards). Read each script's header for its options.

## Procedure

1. Record environment: `ruby -v` (shows `+YJIT`), `uname -m`, which variant flags were used.
2. **Baseline** on the base revision: `git worktree add "$SCRATCH/r2h-base" <rev>` (or `git stash`), `bundle exec rake compile` there, run the chosen command, save output to the scratch dir.
3. **Candidate**: back on the change, `bundle exec rake compile` (mandatory after `ext/` edits), identical command, save output.
4. Repeat each side at least twice if the delta is < 10%; overlapping benchmark-ips error bars = "no measurable change". Check allocation counts (render_bench) for regressions too.
5. Correctness: `CI=1 bundle exec rspec`.
6. Report a table: benchmark, before, after, ratio, error; environment line. Never round away regressions. Remove the worktree (`git worktree remove`).

README tables are updated only when the maintainer asks, with the environment line.

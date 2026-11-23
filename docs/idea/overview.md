# Overview

ruby2html is a RubyGems gem that renders HTML from a plain Ruby block DSL: every HTML5 tag is a
method, text and attribute values are escaped by default, and the output is one compact string.
It works standalone (`Ruby2html::Render`), as Rails `.html.rb` templates, inside ERB through a
helper, in ViewComponent, and through its own `Ruby2html::Component` class.

One renderer, two implementations: a C extension for CRuby (`ext/ruby2html/`) and a pure-Ruby twin
(`lib/gem/ruby2html/render/pure_ruby.rb`) used on JRuby, on TruffleRuby and wherever the extension
is not built. Both produce the same bytes for every input. JRuby adds a small Java escaper
(`ext/java/Ruby2htmlJrubyService.java`).

The repository holds the gem (`lib/gem/`, `ext/`, `ruby2html.gemspec`) and a Rails demo app around
it (`app/`, `config/`) that the feature specs and the request benchmarks run against. The demo app
is not packaged and not deployed.

Readers: Rails developers who want views in Ruby instead of a template language, and AI coding
tools, for which `llms.txt` is the complete user reference in one file.

It is a public project maintained by the developerz.ai agent under the policy in
`.dz/maintainer/maintainer.yml`; breaking changes and major releases stay with the owner.

- How the gem works inside: [`docs/architecture.md`](../architecture.md). This directory does not
  restate it.
- Where things live, and the commands: `CLAUDE.md`, then the nested `ext/CLAUDE.md`,
  `lib/CLAUDE.md`, `spec/CLAUDE.md` and `.github/CLAUDE.md`.

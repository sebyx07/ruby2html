---
name: add-html-tag
description: Add a new HTML element (standard, void, or hyphenated custom element like turbo-frame) to the ruby2html DSL, with specs and docs. Use when a tag method is missing (NoMethodError for e.g. search, slot, svg) or the user asks to support a new element.
---

# Add an HTML tag to ruby2html

Tags are data: `Ruby2html::Render::HTML5_TAGS` / `VOID_ELEMENTS` in `lib/gem/ruby2html/render.rb`. At load, `define_tag(method_name, tag, void)` is called on both `Ruby2html::Native` (C) and `Ruby2html::PureRuby`. No C change is needed unless a limit is hit.

## Steps

1. Add the tag as written in HTML (lowercase, hyphens allowed, e.g. `turbo-frame`) to `HTML5_TAGS`, keeping the list's ordering style. Method name = `tag.tr('-', '_')`.
2. Void element per the HTML spec (no closing tag)? Also add it to `VOID_ELEMENTS` (renders `<tag attrs />`, ignores content and block).
3. Limits (C, `ext/ruby2html/tag_render.c`): name must match `[a-z0-9-]` and be ≤ 32 bytes (`R2H_MAX_TAG_NAME`); at most 200 tags (`R2H_MAX_TAGS`, trampoline pool). Raising a limit is a C change: update the macros/trampoline list and recompile.
4. Name clashes: the new method shadows any same-named method for code running on a `Render` or `Ruby2html::Component` (and wins over component methods/slots inside ViewComponent `html` blocks). Check `Render`/`Component` methods (`render`, `plain`, `component`, `content`, `helpers`, `output`, `current_output`, `link_to`, `image_tag`, `form_with`, `button_to`) and common Rails helpers. `TemplateCompiler` picks the tag up automatically (it reads `HTML5_TAGS`), so in `.html.rb` templates a receiverless call of that name will now be rewritten to the tag; search the demo app and specs for existing uses.
5. Specs in `spec/gem/` inside a `RenderSpecHelper.describe_each` group (runs Native and PureRuby): content, attributes, block, escaping; void form if void.
6. `bundle exec rake compile`, `CI=1 bundle exec rspec spec/gem`, `bundle exec rubocop lib/gem/ruby2html/render.rb`.
7. Docs: mention notable new tags in `llms.txt` (DSL rule 1); `### Added` under `## [Unreleased]` in `CHANGELOG.md`.

## Notes

- SVG/MathML children (`path`, `circle`, `foreignObject`) are case-sensitive and come as a family; propose that as a separate design (the 200-slot pool and `[a-z0-9-]` rule matter) rather than adding one tag.

# Data model

A rendering gem has no database, and the demo app defines no schema. Its "data" is what a template
hands the renderer and what comes out. The rules, in full: [`docs/architecture.md`](../architecture.md)
§ "Tag methods and output rules"; the user-facing form: `llms.txt`.

- **Tag table.** `HTML5_TAGS` and `VOID_ELEMENTS` in `lib/gem/ruby2html/render.rb` are data: each
  entry becomes a method on both implementations at load. Adding a tag edits the table, not the C
  code.
- **Content values.** `nil` renders nothing; a plain `String` is escaped; an `html_safe?` object is
  inserted raw; a Symbol or number is escaped text; anything else goes through `to_s`.
- **Attribute values.** `nil` and `false` omit the attribute, `true` renders a bare name (with
  `data-*`, `aria-*` and a few enumerated attributes keeping `"true"`/`"false"`), a Hash expands
  into prefixed names, an Array joins into space-separated tokens, anything else is escaped
  `to_s`. Names are validated and raise `ArgumentError` when invalid.
- **Output buffer.** One UTF-8 String per top-level render; nested components write into the
  parent's buffer. Input in other encodings is transcoded or raises.
- **Implementation.** `Ruby2html::IMPLEMENTATION` is `Ruby2html::Native` or `Ruby2html::PureRuby`,
  chosen once at load; `Ruby2html.native?` reports it.
- **Public API.** The list that is a contract is in `lib/CLAUDE.md` § "Public API (a contract)".
- **Version.** `Ruby2html::VERSION` in `lib/gem/ruby2html/version.rb`; changing it on `main` is
  what releases ([`deployment`](deployment.md)).

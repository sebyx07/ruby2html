#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit). Cheap and non-blocking: always exits 0.
# Adds a reminder to Claude's context when native or fallback code was edited.
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$path" ] && exit 0

msg=""
case "$path" in
  */ext/ruby2html/*.c|*/ext/ruby2html/*.h|*/ext/ruby2html/extconf.rb)
    msg="C extension edited ($(basename "$path")): run 'bundle exec rake compile' before specs/benchmarks (specs otherwise load the stale .so). Keep the Ruby fallback in lib/gem/ruby2html/ output-identical, RB_GC_GUARD any VALUE whose pointer outlives a call, and no new -Wall -Wextra warnings." ;;
  */lib/gem/ruby2html/render.rb|*/lib/gem/ruby2html/native*|*/lib/gem/ruby2html/fallback*|*/lib/gem/ruby2html/pure*)
    msg="Renderer edited: C and Ruby fallback paths must produce identical output; run 'CI=1 bundle exec rspec spec/gem' (and the pure-Ruby mode if the change touches fallbacks)." ;;
esac
[ -z "$msg" ] && exit 0
jq -cn --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}'
exit 0

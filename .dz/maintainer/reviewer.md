# Reviewer instructions — sebyx07/ruby2html

> Read by the developerz.ai reviewer at EVERY review of this repository, at the reviewed
> commit, as this repo's own layer of the reviewer's prompt — established by dz-runner setup mode.
> It refines the platform rules (a finding is cited or withheld; the bot always discloses)
> and never overrides them. Edit freely; keep it under 12,000 characters — past that it is cut.

## Stack

Ruby + Bundler. The gate is `bin/check` (compile, rubocop, bundle-audit, rspec, the pure-Ruby `rake spec:gem` fallback, brakeman — see bin/check): a change that does not pass it is not proven, whatever its description says.

## Review conventions

- TODO(setup): the conventions a reviewer must hold this repo to (from CLAUDE.md / CONTRIBUTING), each as a rule.

## Gates that matter

- TODO(setup): which checks decide a change here, and what "proven" means for a pull request.

## Never flag

- TODO(setup): what never to flag — generated or vendored files, style a formatter owns, conventions this repo chose on purpose.

# Security Policy

## Supported versions

Only the latest release on [RubyGems](https://rubygems.org/gems/ruby2html) gets security fixes. Fixes land on `main` and ship in the next release.

## Reporting a vulnerability

**Report privately by email to gore.sebyx@yahoo.com. Do not open a public issue or pull request:** both are public, and an AI agent triages them in the open.

Include:

- what is affected: the gem version, Ruby implementation (CRuby, JRuby, TruffleRuby) and, if relevant, Rails version
- steps to reproduce, ideally a small template or script
- the impact as you understand it

There is no fixed response time. Reports are read and fixed as maintainer time allows, and you are credited in the changelog unless you ask not to be.

## In scope

- HTML escaping bypasses (cross-site scripting through text or attribute values, in the C extension, the pure-Ruby implementation or the Java escaper)
- Output that differs between implementations in a way that defeats escaping
- Memory safety in the C extension (`ext/ruby2html`)
- Anything in the published gem or its build that runs code a user did not ask for

## Out of scope

- The demo Rails app in `app/` and `config/`: it is not packaged in the gem
- Output a template explicitly marked as safe, such as `html_safe` strings
- Vulnerabilities in your own application's templates

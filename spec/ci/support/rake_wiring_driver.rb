# frozen_string_literal: true

# Runs the Rakefile the way the CI jobs run rake, and reports what the audit
# wiring does.
#
# The spec (spec/ci/advisory_audit_spec.rb) starts this driver under
# `bundle exec`, with a stub bundle-audit first on PATH and an unlocked matrix
# gemfile outside the repo, and asserts the JSON report the driver writes:
#
#   RUBY2HTML_SPEC_GEMFILE  the unlocked matrix gemfile the audit runs against
#   RUBY2HTML_SPEC_RECORD   the file the stub bundle-audit records its call in
#   RUBY2HTML_SPEC_REPORT   the JSON report this driver writes
#
# Matching the Rakefile's source text proves the wiring on prose alone: the
# report pins what a real rake run does — the prerequisites the tasks carry,
# and what audit:advisories does in CI, outside CI and for the committed root
# Gemfile.

require 'json'
require 'rake'

ROOT = File.expand_path('../../..', __dir__)
Dir.chdir(ROOT)

MATRIX_GEMFILE = ENV.fetch('RUBY2HTML_SPEC_GEMFILE')
RECORD = ENV.fetch('RUBY2HTML_SPEC_RECORD')
REPORT = ENV.fetch('RUBY2HTML_SPEC_REPORT')

# `bundle exec` hands its Bundler environment to every child it starts, and
# RubyGems loads bundler/setup in every child that finds BUNDLER_SETUP or
# RUBYOPT in its environment. The audit script is standalone (it strips the
# Bundler variables for bundle-audit), and the matrix gemfile of the spec is a
# stub that bundler/setup would resolve against the repository lockfile: the
# driver drops the injected variables, so the audit runs outside the caller's
# Bundler environment, the way the script is meant to run.
ENV.delete('RUBYOPT')
ENV.delete('RUBYLIB')
ENV.delete('BUNDLER_SETUP')

# Load the Rakefile the way rake does: at the top level, with the tasks of the
# application.
Rake.application.init
Rake.application.load_rakefile

# The prerequisites a task carries, as the report names them.
def prerequisites_of(task)
  Rake::Task[task].prerequisites.map(&:to_s)
end

# Invokes the audit task and reports what it did: whether the audit ran (the
# stub recorded a call), the call it made and the error it raised.
def run_audit(ci:, gemfile:, stub_status: '0')
  File.delete(RECORD) if File.exist?(RECORD)

  ENV['CI'] = ci ? '1' : nil
  ENV['BUNDLE_GEMFILE'] = gemfile
  ENV['RUBY2HTML_STUB_STATUS'] = stub_status

  task = Rake::Task['audit:advisories']
  task.reenable

  error = nil
  begin
    task.invoke
  rescue StandardError => e
    error = e
  end

  outcome = { 'ran' => File.exist?(RECORD) }
  if outcome['ran']
    argv, cwd, bundle_gemfile = File.read(RECORD).lines.map(&:chomp)
    outcome['call'] = [argv, cwd, bundle_gemfile]
  end
  outcome['raised'] = error.class.name if error
  outcome['message'] = error.message if error
  outcome
end

report = {
  'prerequisites' => {
    'compile' => prerequisites_of('compile'),
    'spec' => prerequisites_of('spec'),
    'spec:gem' => prerequisites_of('spec:gem'),
    'spec:standalone' => prerequisites_of('spec:standalone')
  },
  'without_ci' => run_audit(ci: false, gemfile: File.join(ROOT, 'Gemfile')),
  'with_root_gemfile' => run_audit(ci: true, gemfile: File.join(ROOT, 'Gemfile')),
  'in_ci_with_matrix_gemfile' => run_audit(ci: true, gemfile: MATRIX_GEMFILE),
  'failing_audit' => run_audit(ci: true, gemfile: MATRIX_GEMFILE, stub_status: '1')
}

File.write(REPORT, JSON.generate(report))

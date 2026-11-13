# frozen_string_literal: true

# Steep checks the rules core, and the use cases between it and the
# screens, against sig/, strictly: a call Steep cannot type is an error,
# not a silent untyped. Steep 2.1 skips pattern matching
# (case/in) entirely, so that is an error here too, rather than a part of
# the rules nobody checks. The presentation and the shell are not typed
# yet; the shell would also need Lota's signatures.
target :core do
  signature "sig"
  library "date"
  library "socket"
  check "lib/dot_popper.rb", "lib/dot_popper/*.rb", "lib/dot_popper/use_cases/*.rb"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict) do |hash|
    hash[Steep::Diagnostic::Ruby::UnsupportedSyntax] = :error
  end
end

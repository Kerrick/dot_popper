# frozen_string_literal: true

# Steep checks the rules core against sig/, strictly: a call Steep cannot
# type is an error, not a silent untyped. The presentation and the shell
# are not typed yet; the shell would also need Lota's signatures.
target :core do
  signature "sig"
  check "lib/dot_popper.rb", "lib/dot_popper/*.rb"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end

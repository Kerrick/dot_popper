# frozen_string_literal: true

# Renders the playtest kits' files from playtest/ (PACKAGING.md, "Playtest
# kits"). CI runs it (.github/workflows/kits.yml); so can anyone, to read
# what a kit will ask:
#
#   ruby script/playtest_kit.rb windows OUT [BUILD]   # playtest.ps1
#   ruby script/playtest_kit.rb ipad OUT [BUILD]      # ipad-results.txt
#   ruby script/playtest_kit.rb text TEMPLATE OUT [BUILD] [--crlf]
#
# BUILD is a file of lines naming the build the kit holds; each output
# carries them where its template says @BUILD@. playtest.ps1, and a text
# file given --crlf, get Windows' CRLF line ends.

require_relative "../playtest/kit"

PLAYTEST = File.expand_path("../playtest", __dir__)

def build_lines(path) = path ? File.read(path).strip : "A build made by hand, not by CI."

def stamp(text, build)
  raise ArgumentError, "no @BUILD@ in the template" unless text.include?("@BUILD@")

  text.sub("@BUILD@", build)
end

def crlf(text) = text.gsub(/\r?\n/, "\r\n")

case ARGV
in ["windows", out, *build]
  template = File.read(File.join(PLAYTEST, "playtest.ps1"))
  script = Playtest::PowerShellList.new(Playtest::Checklist.load(:windows)).fill(stamp(template, build_lines(build.first)))
  abort "#{out} would hold bytes outside ASCII, which PowerShell 5.1 misreads" unless script.ascii_only?
  File.binwrite(out, crlf(script))
in ["ipad", out, *build]
  File.write(out, Playtest::ResultsSheet.new(Playtest::Checklist.load(:ipad), build_lines(build.first)).render)
in ["text", template, out, *rest]
  windows = rest.delete("--crlf")
  text = stamp(File.read(template), build_lines(rest.first))
  File.binwrite(out, windows ? crlf(text) : text)
else
  abort "usage: ruby script/playtest_kit.rb windows OUT [BUILD] | ipad OUT [BUILD] | text TEMPLATE OUT [BUILD] [--crlf]"
end

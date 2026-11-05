# frozen_string_literal: true

# Renders the playtest kits' files from playtest/ (PACKAGING.md, "Playtest
# kits"). CI runs it (.github/workflows/kits.yml); so can anyone, to read
# what a kit will ask:
#
#   ruby script/playtest_kit.rb windows OUT [BUILD]       # playtest.ps1
#   ruby script/playtest_kit.rb linux OUT [BUILD]         # playtest.sh
#   ruby script/playtest_kit.rb sheet DEVICE OUT [BUILD]  # mac, ipad, or android results sheet
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

def template(name) = File.read(File.join(PLAYTEST, name))

case ARGV
in ["windows", out, *build]
  list = Playtest::PowerShellList.new(Playtest::Checklist.load(:windows))
  script = list.fill(stamp(template("playtest.ps1"), build_lines(build.first)))
  abort "#{out} would hold bytes outside ASCII, which PowerShell 5.1 misreads" unless script.ascii_only?
  File.binwrite(out, crlf(script))
in ["linux", out, *build]
  list = Playtest::ShellList.new(Playtest::Checklist.load(:linux))
  File.write(out, list.fill(stamp(template("playtest.sh"), build_lines(build.first))))
  File.chmod(0o755, out)
in ["sheet", ("mac" | "ipad" | "android") => device, out, *build]
  File.write(out, Playtest::ResultsSheet.new(Playtest::Checklist.load(device), build_lines(build.first)).render)
in ["text", template, out, *rest]
  windows = rest.delete("--crlf")
  text = stamp(File.read(template), build_lines(rest.first))
  File.binwrite(out, windows ? crlf(text) : text)
else
  abort "usage: ruby script/playtest_kit.rb windows OUT [BUILD] | linux OUT [BUILD] | " \
        "sheet mac|ipad|android OUT [BUILD] | text TEMPLATE OUT [BUILD] [--crlf]"
end

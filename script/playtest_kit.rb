# frozen_string_literal: true

# Renders the playtest kits' files from playtest/ (PACKAGING.md, "Playtest
# kits"). CI runs it (.github/workflows/kits.yml); so can anyone, to read
# what a kit will ask:
#
#   ruby script/playtest_kit.rb windows OUT [BUILD]       # playtest.ps1
#   ruby script/playtest_kit.rb linux OUT [BUILD]         # playtest.sh
#   ruby script/playtest_kit.rb sheet DEVICE OUT [BUILD]  # mac, ios, or android results sheet
#   ruby script/playtest_kit.rb text TEMPLATE OUT [BUILD] [--crlf]
#   ruby script/playtest_kit.rb tag-version REF FLEDGE_YML  # pins a tag's version
#   ruby script/playtest_kit.rb check-build REF BUILD       # BUILD names it
#
# BUILD is a file of lines naming the build the kit holds; each output
# carries them where its template says @BUILD@. playtest.ps1, and a text
# file given --crlf, get Windows' CRLF line ends.
#
# tag-version sets FLEDGE_YML's version to the one REF (GITHUB_REF_NAME)
# builds (Playtest::BuildVersion), in CI's copy only, so that lota fuse
# and every kit's header take a tag's version, and prints it; any other
# ref keeps fledge.yml's. check-build fails unless BUILD's first line
# names REF and that version.

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
in ["sheet", "ipad", out, *build] # the iOS list's name in older workflows
  File.write(out, Playtest::ResultsSheet.new(Playtest::Checklist.load(:ios), build_lines(build.first)).render)
in ["sheet", ("mac" | "ios" | "android") => device, out, *build]
  File.write(out, Playtest::ResultsSheet.new(Playtest::Checklist.load(device), build_lines(build.first)).render)
in ["text", template, out, *rest]
  windows = rest.delete("--crlf")
  text = stamp(File.read(template), build_lines(rest.first))
  File.binwrite(out, windows ? crlf(text) : text)
in ["tag-version", ref, fledge]
  text = File.read(fledge)
  version = Playtest::BuildVersion.of(ref, fallback: YAML.safe_load(text).fetch("version"))
  File.write(fledge, version.pin(text)) if version.tag?
  puts version.app
in ["check-build", ref, build]
  line = File.foreach(build).first.to_s.chomp
  fledge = YAML.load_file(File.expand_path("../fledge.yml", __dir__)).fetch("version")
  version = Playtest::BuildVersion.of(ref, fallback: fledge)
  abort "#{build} begins #{line.inspect}, not Dot Popper #{ref} at version #{version.app}" unless version.names?(line)
  puts "#{build} names Dot Popper #{ref} at version #{version.app}"
else
  abort "usage: ruby script/playtest_kit.rb windows OUT [BUILD] | linux OUT [BUILD] | " \
        "sheet mac|ios|android OUT [BUILD] | text TEMPLATE OUT [BUILD] [--crlf] | " \
        "tag-version REF FLEDGE_YML | check-build REF BUILD"
end

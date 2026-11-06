# frozen_string_literal: true

require "yaml"

# The playtest kits' hand checks (playtest/checks.yml) and what they are
# rendered into: the Windows kit's playtest.ps1 and the Linux kit's
# playtest.sh, which ask them one at a time, and the macOS, iPad, and
# Android kits' results sheets, which the player fills in. Nothing here loads the game
# or Lota; script/playtest_kit.rb runs it in CI
# (.github/workflows/kits.yml), and test/playtest_kit_test.rb tests it.
module Playtest
  CHECKS = File.expand_path("checks.yml", __dir__)

  # The desktop systems, which share checks.yml's desktop list.
  DESKTOPS = %i[windows mac linux].freeze

  # The kinds of answer a check can ask for, and how each is prompted.
  ANSWERS = {
    "yes_no" => "y / n / skip",
    "yes_no_not_shown" => "y / n / not shown / skip",
    "rating" => "1 to 5 / skip",
    "choice" => "one of the choices / skip",
    "paste" => "y / n / skip, then the pasted text",
    "describe" => "your own words"
  }.freeze

  # One further answer a check asks for, after its own.
  class Part < Data.define(:ask, :answer, :scale, :options)
    def self.from(hash) = new(ask: hash["ask"].to_s, answer: hash["answer"], scale: hash["scale"], options: Array(hash["options"]))
  end

  # One hand check, as checks.yml describes it for one +device+: a field
  # that differs by system is a mapping, of which the device's entry, or
  # else default, is the one it reads.
  class Check < Data.define(:id, :ask, :answer, :try, :restart, :after, :group, :parts, :quotes, :scale, :options)
    def self.from(hash, device)
      words = ->(key) { (value = hash[key]).is_a?(Hash) ? value.fetch(device.to_s) { value["default"] } : value }
      new(id: hash.fetch("id").to_s, ask: words["ask"].to_s, answer: hash["answer"], try: words["try"],
          restart: hash["restart"] == true, after: words["after"], group: hash["group"],
          parts: Array(hash["parts"]).map { Part.from(it) }, quotes: Array(hash["quotes"]).map(&:to_s),
          scale: hash["scale"], options: Array(hash["options"]))
    end

    def controller? = group == "controller"

    # Every answer the check asks for: its own, if it has one, then its
    # parts'.
    def answers = [(Part.new(ask:, answer:, scale:, options:) if answer), *parts].compact

    # Every piece of wording a player reads for this check.
    def wording = [try, ask, after, *parts.map(&:ask)].compact
  end

  # The checks for one device, in the order they are asked.
  class Checklist < Data.define(:device, :checks)
    def self.load(device, path = CHECKS)
      list = DESKTOPS.include?(device.to_sym) ? "desktop" : device.to_s
      new(device: device.to_sym, checks: YAML.load_file(path).fetch(list).map { Check.from(it, device) })
    end

    def each(&) = checks.each(&)
  end

  # A rendering that takes the place of one marked line of a template.
  module Filling
    MARK = "# @CHECKS@"

    # +template+ with MARK's line replaced by #render.
    def fill(template)
      raise ArgumentError, "the template has no #{MARK} line" unless template.include?(MARK)

      template.sub(/^#{Regexp.escape(MARK)}$/) { render }
    end
  end

  # The PowerShell array playtest.ps1 asks from: one hashtable a check,
  # with single-quoted strings, in which only a quote needs escaping.
  class PowerShellList < Data.define(:checklist)
    include Filling

    def render
      rows = checklist.checks.map { "  #{table(it)}" }
      "$Checks = @(\n#{rows.join(",\n")}\n)"
    end

    private

    def table(check)
      fields = { "Id" => check.id, "Ask" => check.ask, "Answer" => check.answer.to_s, "Try" => check.try.to_s,
                 "Restart" => check.restart, "After" => check.after.to_s, "Group" => check.group.to_s,
                 "Scale" => check.scale.to_s, "Options" => check.options,
                 "Parts" => check.parts.map { part(it) } }
      "@{ #{fields.map { |key, value| "#{key} = #{literal(value)}" }.join("; ")} }"
    end

    def part(part)
      { "Ask" => part.ask, "Answer" => part.answer.to_s, "Scale" => part.scale.to_s, "Options" => part.options }
    end

    def literal(value)
      case value
      in true then "$true"
      in false then "$false"
      in String then "'#{value.gsub("'", "''")}'"
      in Array then "@(#{value.map { literal(it) }.join(", ")})"
      in Hash then "@{ #{value.map { |key, inner| "#{key} = #{literal(inner)}" }.join("; ")} }"
      end
    end
  end

  # The checks as playtest.sh asks them: a Bash function a check, which
  # calls the script's begin_check, answer, and end_check, and the lists
  # of every check's id and the controller checks' ids. Strings are
  # single-quoted, in which only a quote needs escaping.
  class ShellList < Data.define(:checklist)
    include Filling

    def render
      ids = checklist.checks.map(&:id)
      [%(CHECK_IDS=(#{ids.join(" ")})),
       %(CONTROLLER_IDS=" #{checklist.checks.select(&:controller?).map(&:id).join(" ")} "),
       *checklist.checks.map { function(it) }].join("\n")
    end

    private

    def function(check)
      calls = [call("begin_check", check.id, check.ask, check.try.to_s, check.restart.to_s)]
      check.answers.each do |part|
        label = part.ask == check.ask ? "answer" : part.ask
        calls << call("answer", part.answer, label, part.scale.to_s, part.options.join("|"))
      end
      calls << call("end_check", check.after.to_s)
      "check_#{check.id}() {\n#{calls.map { "  #{it}" }.join("\n")}\n}"
    end

    def call(name, *arguments) = [name, *arguments.map { quote(it) }].join(" ")

    # A block, since in a replacement String \' would mean what follows
    # the match.
    def quote(text) = "'#{text.gsub("'") { %q('\\'') }}'"
  end

  # The version a kit's app is built as, from the ref CI builds (+ref+,
  # such as v0.8.2 or trunk): a tag's own, without its leading v, or else
  # +fallback+, fledge.yml's, as a local build takes it.
  #
  # A release candidate's tag, v0.8.2-rc.1, builds its base version,
  # 0.8.2: macOS's and iOS's CFBundleShortVersionString and Windows' file
  # version take only numbers, so an rc's suffix has no form every
  # platform allows. The kit's header still names the tag beside it.
  class BuildVersion < Data.define(:ref, :app)
    TAG = /\Av(?<base>\d+\.\d+\.\d+)(?:-[0-9A-Za-z.]+)?\z/

    def self.of(ref, fallback:)
      match = TAG.match(ref.to_s)
      new(ref: ref.to_s, app: match ? match[:base] : fallback.to_s)
    end

    def tag? = TAG.match?(ref)

    # +text+, a fledge.yml, with its version: line set to this version.
    def pin(text)
      raise ArgumentError, "no version: line in fledge.yml" unless text.match?(/^version: /)

      text.sub(/^version: .*$/, "version: #{app.inspect}")
    end

    # Whether +line+, the first of a kit's build lines, names this build:
    # its ref, and the version its app was given.
    def names?(line) = line.start_with?("Dot Popper #{ref},") && line.end_with?(", version #{app}")
  end

  # A kit's results sheet, such as the iOS kit's ios-results.txt: the
  # build it tests, a few lines about the device, then each check with its
  # blanks, ready to fill in.
  class ResultsSheet < Data.define(:checklist, :build)
    WIDTH = 76

    # The sheet's title, and the lines about the device it asks first.
    DEVICES = {
      ios: ["Dot Popper iPhone and iPad playtest results",
            ["Date played: ->", "iPhone or iPad, and its model (Settings > General > About): ->",
             "iOS or iPadOS version: ->", "Xcode version on the Mac: ->"]],
      android: ["Dot Popper Android playtest results (experimental)",
                ["Date played: ->", "Phone model (Settings > About device): ->",
                 "Android version (Settings > About device > Version): ->",
                 "How you installed it (adb install, or opening the APK on the phone): ->"]],
      mac: ["Dot Popper macOS playtest results",
            ["Date played: ->", "Mac model and chip (Apple menu > About This Mac): ->", "macOS version: ->",
             "Display (built-in or external, its size and refresh rate): ->",
             "Controller (none, or which one): ->"]]
    }.freeze

    def render
      title, device = DEVICES.fetch(checklist.device)
      [title, "=" * title.length, "", *build.lines(chomp: true).map { "  #{it}" }, "", *intro, "", *device, "",
       *checklist.checks.flat_map { [*check(it), ""] }, "Thank you!"].join("\n") + "\n"
    end

    private

    def intro
      wrap("Fill in each answer after its arrow (->), in your own words where it asks. " \
           "Skip anything you can't try. Then save this file and send it back, with any screenshots.")
    end

    def check(check)
      lines = wrap("#{check.id}. #{"(Only with a controller.) " if check.controller?}#{check.ask}", indent: "    ")
      lines += wrap("Try: #{check.try}", indent: "    ", first: "    ") if check.try
      check.answers.each do |part|
        label = part.ask == check.ask ? "Answer" : part.ask.sub(/:\z/, "")
        lines += wrap("#{label} (#{prompt(part)}): ->", indent: "      ", first: "    ")
      end
      lines += ["    Pasted result:", "", "", ""] if check.answers.any? { it.answer == "paste" }
      lines += wrap("Then: #{check.after}", indent: "    ", first: "    ") if check.after
      lines + ["    Note: ->"]
    end

    def prompt(part)
      case part.answer
      when "rating" then "#{part.scale}, or skip"
      when "choice" then part.options.join(" / ")
      when "paste" then "y / n / skip; paste it under the next line"
      else ANSWERS.fetch(part.answer)
      end
    end

    def wrap(text, indent: "", first: "")
      text.split.each_with_object([+first]) do |word, lines|
        if lines.last.strip.empty? then lines[-1] = "#{lines.last}#{word}"
        elsif lines.last.length + word.length + 1 <= WIDTH then lines[-1] = "#{lines.last} #{word}"
        else lines << "#{indent}#{word}"
        end
      end
    end
  end
end

# frozen_string_literal: true

require "yaml"

# The playtest kits' hand checks (playtest/checks.yml) and what they are
# rendered into: the Windows kit's playtest.ps1, which asks them one at a
# time, and the iPad kit's ipad-results.txt, which the player fills in.
# Nothing here loads the game or Lota; script/playtest_kit.rb runs it in
# CI (.github/workflows/kits.yml), and test/playtest_kit_test.rb tests it.
module Playtest
  CHECKS = File.expand_path("checks.yml", __dir__)

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

  # One hand check, as checks.yml describes it.
  class Check < Data.define(:id, :ask, :answer, :try, :restart, :after, :group, :parts, :quotes, :scale, :options)
    def self.from(hash)
      new(id: hash.fetch("id").to_s, ask: hash["ask"].to_s, answer: hash["answer"], try: hash["try"],
          restart: hash["restart"] == true, after: hash["after"], group: hash["group"],
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
      new(device:, checks: YAML.load_file(path).fetch(device.to_s).map { Check.from(it) })
    end

    def each(&) = checks.each(&)
  end

  # The PowerShell array playtest.ps1 asks from: one hashtable a check,
  # with single-quoted strings, in which only a quote needs escaping.
  class PowerShellList < Data.define(:checklist)
    MARK = "# @CHECKS@"

    def render
      rows = checklist.checks.map { "  #{table(it)}" }
      "$Checks = @(\n#{rows.join(",\n")}\n)"
    end

    # +template+ with MARK's line replaced by the list.
    def fill(template)
      raise ArgumentError, "the template has no #{MARK} line" unless template.include?(MARK)

      template.sub(/^#{Regexp.escape(MARK)}$/) { render }
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

  # The iPad kit's ipad-results.txt: the build it tests, a few lines
  # about the iPad, then each check with its blanks, ready to fill in.
  class ResultsSheet < Data.define(:checklist, :build)
    WIDTH = 76

    def render
      [heading, "", *build.lines(chomp: true).map { "  #{it}" }, "", *intro, "", *device, "",
       *checklist.checks.flat_map { [*check(it), ""] }, *ending].join("\n") + "\n"
    end

    private

    def heading = "Dot Popper iPad playtest results\n#{"=" * 32}"

    def intro
      wrap("Fill in each answer after its arrow (->), in your own words where it asks. " \
           "Skip anything you can't try. Then save this file and send it back, with any screenshots.")
    end

    def device
      ["Date played: ->", "iPad model (Settings > General > About): ->", "iPadOS version: ->",
       "Xcode version on the Mac: ->"]
    end

    def check(check)
      lines = ["#{check.id}. #{"(Only with a controller.) " if check.controller?}#{check.ask}"]
      lines = wrap(lines.first, indent: "    ", first: "")
      lines += wrap("Try: #{check.try}", indent: "    ", first: "    ") if check.try
      check.answers.each do |part|
        label = part.ask == check.ask ? "Answer" : part.ask.sub(/:\z/, "")
        lines += wrap("#{label} (#{prompt(part)}): ->", indent: "      ", first: "    ")
      end
      lines += ["    Pasted result:", "", "", ""] if check.answers.any? { it.answer == "paste" }
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

    def ending = ["Thank you!"]

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

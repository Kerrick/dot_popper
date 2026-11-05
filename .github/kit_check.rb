# frozen_string_literal: true

# CI's side of the scripted kits' tests (kits.yml), for Windows'
# playtest.ps1 and Linux's playtest.sh: the answers a player would type,
# one line each, in the order the script asks, and then a check of the
# dot-popper-results.txt it wrote. Both read playtest/checks.yml, so a new
# check is answered and checked with no change here.
#
#   ruby .github/kit_check.rb answers windows|linux OUT
#   ruby .github/kit_check.rb results windows|linux FILE

require_relative "../playtest/kit"

# The facts each system's results must hold.
FACTS = {
  "windows" => { "the graphics card" => /^graphics: /, "the displays" => /^display .*display scale/,
                 "the Windows build" => /^windows: .*build \d+/, "the controllers" => /^controllers?: / },
  "linux" => { "the system" => /^system: \S/, "the kernel" => /^kernel: Linux/, "OpenGL" => /^opengl: OpenGL/,
               "the displays" => /^displays: / }
}.freeze

# The answer typed for one part, with what follows it.
def typed(part, id)
  case part.answer
  when "yes_no" then ["y"]
  when "yes_no_not_shown" then ["ns"]
  when "rating" then ["4"]
  when "choice" then ["2"]
  when "paste" then ["y", "Dot Popper: 12 points", "pasted by CI for check #{id}", ""]
  else ["described by CI for check #{id}", ""]
  end
end

def answers(checklist)
  # A controller, so its checks are asked too.
  lines = ["y"]
  checklist.each do |check|
    check.answers.each { lines.concat(typed(it, check.id)) }
    lines << "note from CI for check #{check.id}"
  end
  lines
end

def results(checklist, text)
  problems = []
  checklist.each do |check|
    block = text[/^\[#{check.id}\] .*?(?=^\[\d+\] |^== |\z)/m]
    next problems << "check #{check.id} is missing" unless block

    problems << "check #{check.id} was not answered" if block.match?(/not answered|not asked|unclear/)
    problems << "check #{check.id} lost its note" unless block.include?("note: note from CI for check #{check.id}")
  end
  problems << "the pasted result is missing" unless text.include?("pasted by CI for check 9")
  problems << "check 8's 'ns' was not written as 'not shown'" unless text[/^\[8\] .*?answer: not shown/m]
  FACTS.fetch(checklist.device.to_s).merge(
    "the restart for check 2" => /^Dot Popper started \(again, for check 2\)/,
    "DOT_POPPER_PERF's lines" => /frames a second, longest frame/,
    "a clean exit" => /^exit code: 0$/, "the save folder" => /^== The game's save folder/, "the end" => /^finished: /
  ).each { |what, pattern| problems << "no sign of #{what}" unless text.match?(pattern) }
  # A round finishes within a session only when the bot lets the clock
  # run out, so a missing rounds.csv is worth a look, not a failure.
  puts "::warning::no rounds.csv in the results: no round finished" unless text.match?(/^-- rounds\.csv$/)
  problems
end

case ARGV
in ["answers", ("windows" | "linux") => device, out]
  # binwrite, since a text-mode write on Windows would make each \r\n
  # into \r\r\n, an empty answer after every line.
  File.binwrite(out, answers(Playtest::Checklist.load(device)).join("\r\n") + "\r\n")
in ["results", ("windows" | "linux") => device, path]
  problems = results(Playtest::Checklist.load(device), File.read(path, encoding: "UTF-8"))
  problems.each { puts "::error::#{it}" }
  puts problems.empty? ? "dot-popper-results.txt has every check and every fact" : "#{problems.size} problems"
  exit(problems.empty? ? 0 : 1)
else
  abort "usage: ruby .github/kit_check.rb answers windows|linux OUT | results windows|linux FILE"
end

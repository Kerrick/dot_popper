# frozen_string_literal: true

# CI's side of the Windows kit's test (kits.yml): the answers a player
# would type into playtest.ps1, one line each, in the order it asks, and
# then a check of the dot-popper-results.txt it wrote. Both read
# playtest/checks.yml, so a new check is answered and checked with no
# change here.
#
#   ruby .github/windows_kit_check.rb answers OUT
#   ruby .github/windows_kit_check.rb results FILE

require_relative "../playtest/kit"

CHECKLIST = Playtest::Checklist.load(:windows)

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

def answers
  # A controller, so its checks are asked too.
  lines = ["y"]
  CHECKLIST.each do |check|
    check.answers.each { lines.concat(typed(it, check.id)) }
    lines << "note from CI for check #{check.id}"
  end
  lines
end

def results(path)
  text = File.read(path, encoding: "UTF-8")
  problems = []
  CHECKLIST.each do |check|
    block = text[/^\[#{check.id}\] .*?(?=^\[\d+\] |^== |\z)/m]
    next problems << "check #{check.id} is missing" unless block

    problems << "check #{check.id} was not answered" if block.match?(/not answered|not asked|unclear/)
    problems << "check #{check.id} lost its note" unless block.include?("note: note from CI for check #{check.id}")
  end
  problems << "the pasted result is missing" unless text.include?("pasted by CI for check 9")
  problems << "check 8's 'ns' was not written as 'not shown'" unless text[/^\[8\] .*?answer: not shown/m]
  {
    "the graphics card" => /^graphics: /, "the displays" => /^display .*display scale/,
    "the Windows build" => /^windows: .*build \d+/, "the controllers" => /^controllers?: /,
    "the restart for check 2" => /^Dot Popper started \(again, for check 2\)/,
    "DOT_POPPER_PERF's lines" => /frames a second, longest frame/,
    "a clean exit" => /^exit code: 0$/, "the save folder" => /^== The game's save folder/, "the end" => /^finished: /
  }.each { |what, pattern| problems << "no sign of #{what}" unless text.match?(pattern) }
  # A round finishes within a session only when the bot lets the clock
  # run out, so a missing rounds.csv is worth a look, not a failure.
  puts "::warning::no rounds.csv in the results: no round finished" unless text.match?(/^-- rounds\.csv$/)
  problems
end

case ARGV
in ["answers", out]
  File.write(out, answers.join("\r\n") + "\r\n")
in ["results", path]
  problems = results(path)
  problems.each { puts "::error::#{it}" }
  puts problems.empty? ? "dot-popper-results.txt has every check and every fact" : "#{problems.size} problems"
  exit(problems.empty? ? 0 : 1)
else
  abort "usage: ruby .github/windows_kit_check.rb answers OUT | results FILE"
end

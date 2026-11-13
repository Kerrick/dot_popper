# frozen_string_literal: true

require "prism"
require "test_helper"

# GLOSSARY.md is the game's one language (AGENTS.md, "Words"). Each row's
# "Don't say" column lists words its term replaces, and this test reads
# that column itself, so a new row is held to with no change here. A
# forbidden word fails wherever it appears: in the game's names (Ruby, RBS
# and shader identifiers, split at underscores and capitals), its strings,
# its comments, its tests and scripts, its documents and the playtest kits'
# READMEs. A word the glossary writes with a capital (a screen's name, as
# "Finale") is looked for with that capital only, and a single word with
# its plural too.
#
# A word is forbidden for its row's meaning only, and a search cannot tell
# meanings apart, so:
#
# - An entry the glossary itself limits to one meaning ("records meaning
#   every statistic"), or a word that is also a term of the glossary
#   ("streak", the daily one), is not looked for.
# - EVERYDAY words have a common meaning the game uses all through its
#   code and documents, so they are looked for only in the strings of
#   lib/dot_popper/presentation and lib/dot_popper/privacy, which hold
#   every word a player reads.
# - OTHER_MEANINGS allows a word on a line where a pattern for its other
#   meaning matches, and says why.
#
# So it cannot catch "records" meaning every statistic, "streak" meaning
# dots in a row, an EVERYDAY word in a name, a comment or a document ("run"
# for a game), a forbidden meaning on a line that an OTHER_MEANINGS pattern
# also matches, a word the glossary has no row for, or a second word for a
# term that its "Don't say" column does not list (as "fresh" once was for
# "bright").
class GlossaryTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GLOSSARY = File.join(ROOT, "GLOSSARY.md")

  # Not the game's own words: the glossary, and this test, which name the
  # words; decisions recorded once and never reworded (the adr skill);
  # playtest reports, which quote players and describe the game as it was;
  # and the maintainer's reading list, in the books' words.
  UNCHECKED = [%r{\AGLOSSARY\.md\z}, %r{\Atest/glossary_test\.rb\z}, %r{\Adoc/adr/}, %r{\Adoc/playtests/},
               %r{\AINSIPIRATION\.md\z}].freeze

  # Words looked for only in what players read, and their everyday meaning.
  EVERYDAY = {
    "run" => "a program, a test or a clock runs, and a run of text is drawn in one style",
    "round" => "numbers are rounded, and shapes are round",
    "code" => "programs are code, a friend group has a join code, and a player has a private code",
    "token" => "a friend group's server knows a player by a token, and the Microsoft Store names Pro by an in-app offer token",
    "flag" => "TutorialFlag remembers the tutorial, and the environment's settings are flags"
  }.freeze

  # For each word, [a pattern for its other meaning, why it is not the
  # glossary's], matched against the whole line.
  OTHER_MEANINGS = {
    "pops" => [[/\b(it|dot|there|player|which|game|that|one|fits) pops\b|\bpops (it|the|a|them|one|out|exactly|with)\b/i,
                "the verb, as in \"a tap pops it\""],
               [/"pops"|\bpops[ ,]mistakes\b|:pops\b|\bpops=/,
                "the key stats.txt and games.csv save the dots popped under, which builds in players' hands read"]],
    "crown" => [[/:crown\b|\bcrown:|crown glyph/, "the glyph drawn as a crown (Shell::Glyphs), named for its shape"]],
    "code" => [[/\b(join|group|private|that|a|other's) code\b|"Code"/i, "a friend group's join code, and a player's private code"]],
    "token" => [[/player's token|no token is sent/, "the token a friend group's server knows a player by"]],
    "run" => [[/\bruns? (the|them|`)|"run"/, "a program runs, and Lota's own run command"]],
    "a play" => [[/\ba play (purchase|build|store|console|billing)/i, "Google Play"]],
    "trial" => [[/\btrials? or (a )?demos?\b|trial\|demo/, "naming the words, to say nothing calls Free that"]],
    "demo" => [[/\btrials? or (a )?demos?\b|trial\|demo/, "naming the words, to say nothing calls Free that"]],
    "lifetime" => [[/particle.?lifetime|\.lifetime\b|def lifetime/i, "how long a particle lives, as LÖVE's ParticleSystem names it"]],
    "serial" => [[/\.serial\b/, "a certificate's serial number"]],
    "skin" => [[/\bskin (tone|color)s?\b/, "the color of a person's skin, which no name or emoji in the game picks"]],
    "records" => [[/rows\("Records"/, "the heading of the Stats screen's card of records, each a record in the glossary's sense"]]
  }.freeze

  # A row of the glossary's table: its term, and the words it replaces.
  Row = Data.define(:term, :forbidden)

  # One use of a forbidden word: where, the word, and the line.
  Use = Data.define(:path, :line, :word, :term, :text) do
    def to_s = "#{path}:#{line}: \"#{word}\" (the glossary says #{term}): #{text.strip[0, 140]}"
  end

  # One piece of a file to look in: its line, its text, and its kind
  # (:name, :string, :comment or :text), with the whole line for context.
  Piece = Data.define(:line, :text, :kind, :context)

  def self.rows
    File.readlines(GLOSSARY).filter_map do |line|
      cells = line.split("|").map(&:strip)
      next unless cells[1]&.start_with?("**")

      Row.new(term: cells[1].delete("*"), forbidden: cells[3].to_s.split(",").map(&:strip).reject(&:empty?))
    end
  end

  def self.terms = rows.flat_map { it.term.downcase.split(" / ") }

  # The words to look for, each as [word, term]: an entry with its quotes
  # and a leading "or" dropped, and none the glossary limits to a meaning
  # or uses as a term.
  def self.forbidden
    rows.flat_map { |row| row.forbidden.map { [it.delete('"').sub(/\Aor /, ""), row.term] } }
        .reject { |word, _| word.include?(" meaning ") || terms.include?(word.downcase) }
  end

  # A word as a pattern: whole, a single word with its plural too, and in
  # any case unless the glossary capitalizes it.
  def self.pattern(word)
    plural = word.include?(" ") ? "" : "(?:e?s)?"
    Regexp.new("(?<![[:alnum:]])#{Regexp.escape(word).gsub("\\ ", "\\s+")}#{plural}(?![[:alnum:]])",
               word.match?(/\A[[:upper:]]/) ? nil : Regexp::IGNORECASE)
  end

  # Names as words: dot_size_test and DotSizeTest both read "dot size test".
  def self.words_of_names(text) = text.gsub(/([[:lower:]\d])([[:upper:]])/, '\1 \2').tr("_", " ")

  def test_the_glossary_can_be_read
    words = self.class.forbidden.map(&:first)

    assert_operator words.size, :>=, 20, "GLOSSARY.md's table could not be read"
    assert_includes words, "Finale"
    refute_includes words, "streak", "a term of the glossary is not forbidden"
    refute_includes words, "records", "a word forbidden in one meaning only is not looked for"
  end

  def test_a_slip_is_found_and_another_meaning_is_not
    pieces = [Piece.new(1, "Finale Screen", :name, "class FinaleScreen"), Piece.new(2, "# the best score", :comment, "# the best score"),
              Piece.new(3, "# a tap pops it", :comment, "# a tap pops it"), Piece.new(4, "# a run of text", :comment, "# a run of text"),
              Piece.new(5, "a run", :string, "\"a run\"")]

    found = uses_in("lib/dot_popper/presentation/example.rb", pieces, players_read: true).map { [it.line, it.word] }

    assert_equal [[1, "Finale"], [2, "best"], [5, "run"]], found
  end

  def test_no_forbidden_word_is_used_for_its_term
    uses = texts.flat_map { |path, pieces, players_read| uses_in(path, pieces, players_read:) }

    assert_empty uses.map(&:to_s), "Say GLOSSARY.md's word, or, where the word means something else, add that to OTHER_MEANINGS with why"
  end

  private

  # The checks, as [word, term, pattern], by the first word of each in
  # lower case, so a piece is matched only against the words it has.
  def checks
    @checks ||= self.class.forbidden.map { |word, term| [word, term, self.class.pattern(word)] }
                    .group_by { |word, _, _| word.downcase.split.first }
  end

  def checks_for(text)
    words = text.downcase.scan(/[[:alnum:]]+/).uniq
    words.flat_map { checks.fetch(it, []) + checks.fetch(it.sub(/e?s\z/, ""), []) }.uniq
  end

  # +players_read+ is true for a file whose strings a player reads. A word
  # two rows forbid is one use, naming both terms.
  def uses_in(path, pieces, players_read:)
    uses = pieces.flat_map do |piece|
      checks_for(piece.text).filter_map do |word, term, pattern|
        next unless piece.text.match?(pattern)
        next if EVERYDAY.key?(word.downcase) && !(players_read && piece.kind == :string)
        next if other_meaning?(word, piece.context)

        Use.new(path:, line: piece.line, word:, term:, text: piece.text)
      end
    end
    uses.group_by { [it.line, it.word, it.text] }.map { |_, same| same.first.with(term: same.map(&:term).uniq.join(" or ")) }
  end

  def other_meaning?(word, context)
    lines = [context, self.class.words_of_names(context)]
    OTHER_MEANINGS.fetch(word.downcase, []).any? { |meaning, _why| lines.any? { it.match?(meaning) } }
  end

  # Every file looked in, as [path, its Pieces, whether players read its
  # strings]. Ruby is read by its tokens, so a name is split into words;
  # everything else line by line, with names split in signatures and
  # shaders, and only in `code` in Markdown, where prose has capitals.
  def texts
    ruby = Dir.glob("{lib,bin,script,test}/**/*.rb", base: ROOT) + %w[main.rb conf.rb]
    other = Dir.glob("{sig/**/*.rbs,assets/shaders/**/*.glsl,*.md,doc/**/*.md,playtest/*.{txt,sh,ps1}}", base: ROOT)
    files = (ruby + other).reject { |path| UNCHECKED.any? { path.match?(it) } }
    files.map do |path|
      pieces = path.end_with?(".rb") ? ruby_pieces(path) : plain_pieces(path)
      [path, pieces, path.start_with?("lib/dot_popper/presentation/", "lib/dot_popper/privacy/")]
    end
  end

  def plain_pieces(path)
    File.readlines(File.join(ROOT, path)).each_with_index.map do |line, i|
      text = path.end_with?(".md", ".txt", ".sh", ".ps1") ? line.gsub(/`[^`]*`/) { self.class.words_of_names(it) } : self.class.words_of_names(line)
      Piece.new(i + 1, text, :text, line)
    end
  end

  def ruby_pieces(path)
    source = File.read(File.join(ROOT, path))
    lines = source.lines
    Prism.lex(source).value.filter_map do |token, _state|
      next if token.value.strip.empty?

      kind = { COMMENT: :comment, STRING_CONTENT: :string }.fetch(token.type, :name)
      line = token.location.start_line
      Piece.new(line, kind == :name ? self.class.words_of_names(token.value) : token.value, kind, lines[line - 1].to_s)
    end
  end
end

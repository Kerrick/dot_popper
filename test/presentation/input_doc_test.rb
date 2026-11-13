# frozen_string_literal: true

require_relative "presentation_helper"

# doc/design/input.md's keyboard table says which keys each screen takes,
# and so do the screens' own tables (Screens::Screen#key_bindings) and the
# InputHandler's (InputHandler::KEY_BINDINGS). This holds the document to the
# tables, so neither can drift: a key the document names that no table
# binds fails, and so does a key a table binds that the document misses.
class InputDocTest < Minitest::Test
  include PresentationTest

  DOC = File.expand_path("../../doc/design/input.md", __dir__)

  # The screens that take keys of their own, by the name the document's
  # "Where" column gives them; "Every screen" is the InputHandler's.
  WHERE = { "Pro offer" => Screens::Offer, "Change Server" => Screens::ChangeServer, "Friend groups" => Screens::FriendGroups,
            "Home" => Screens::Home, "Settings" => Screens::Settings, "Every screen" => InputHandler }.freeze

  # The document's words for groups of keys.
  WORDS = { "letters" => ("a".."z").map(&:to_sym), "digits" => ("0".."9").map(&:to_sym), "hyphen" => [:minus] }.freeze

  def test_the_keyboard_table_names_exactly_the_keys_each_table_binds
    WHERE.each do |where, owner|
      bound = owner::KEY_BINDINGS.flat_map { chords(it) }.uniq.sort
      documented = rows.select { |_, at| at.include?(where) }.flat_map { |keys, _| parse(keys) }.uniq.sort

      assert_equal bound, documented, where
    end
  end

  def test_every_screen_that_takes_keys_is_in_the_table
    owners = Screens.constants.map { Screens.const_get(it) }.select { it.is_a?(Class) && it.const_defined?(:KEY_BINDINGS, false) }

    assert_empty owners - WHERE.values
  end

  private

  # A binding's keys as the document writes them: "ctrl+v" for a chord
  # of the system's command key, "alt+enter" for one of Alt or Cmd, and
  # the key alone otherwise.
  def chords(binding)
    prefix = if binding.with == KeyBinding::COMMAND then "ctrl+"
             elsif binding.with == %i[alt command] then "alt+"
             else ""
             end
    binding.keys.map { "#{prefix}#{it}" }
  end

  # The keyboard table's rows: [keys, where].
  def rows
    section = File.read(DOC)[/^## Keyboard\n(.*?)^## /m, 1]
    section.lines.grep(/\A\| /).drop(2).map { it.split("|").map(&:strip).reject(&:empty?).first(2) }.reject { |keys, _| keys == "Any key" }
  end

  # The keys a row's first column names, as #chords writes them.
  def parse(text)
    text.gsub(/\(.*?\)/, "").split(/,| or /).map(&:strip).reject(&:empty?).flat_map do |word|
      next [] if word.start_with?("Cmd+")

      prefix, key = word.include?("+") ? word.split("+", 2).then { |mod, k| ["#{mod.downcase}+", k] } : ["", word]
      (WORDS[key.downcase] || [key.downcase.tr(" ", "_").to_sym]).map { "#{prefix}#{it}" }
    end
  end
end

# frozen_string_literal: true

module DotPopper
  # Which screens a game's records are compared with. With R fixed, a
  # field's size in square radii decides how crowded it gets, so a phone's
  # game and a big monitor's are different contests: a record is kept for
  # each SMALL, MEDIUM, or LARGE field (Rules::SMALL_FIELD_BELOW and
  # LARGE_FIELD_FROM), and one more for standard dots. +name+ is how a
  # save file writes it, and never changes, since builds in players' hands
  # wrote it: standard dots' class is "fitted" there.
  class SizeClass < Data.define(:name)
    def initialize(name:) = super(name: -name)

    SMALL = new(name: "small")
    MEDIUM = new(name: "medium")
    LARGE = new(name: "large")
    # Every game with standard dots (DotSizing::STANDARD): its field is
    # about as crowded on any screen, so they are one class.
    STANDARD = new(name: "fitted")
    ALL = [SMALL, MEDIUM, LARGE, STANDARD].freeze

    # The class of a field, by its area in square radii.
    def self.of(field)
      area = field.width * field.height / (field.radius**2)
      if area < Rules::SMALL_FIELD_BELOW then SMALL
      elsif area < Rules::LARGE_FIELD_FROM then MEDIUM
      else LARGE
      end
    end

    # The class a save file names, or nil for a name it does not know.
    def self.named(name) = ALL.find { it.name == name }

    def to_s = name
  end
end

# frozen_string_literal: true

module DotPopper
  # Which screens a round's records are compared with. With R fixed, a
  # field's size in square radii decides how crowded it gets, so a phone's
  # round and a big monitor's are different contests: a best is kept for
  # each SMALL, MEDIUM, or LARGE field (Rules::SMALL_FIELD_BELOW and
  # LARGE_FIELD_FROM), and one more for dots sized to the screen. +name+ is how a save file writes it.
  class SizeClass < Data.define(:name)
    def initialize(name:) = super(name: -name)

    SMALL = new(name: "small")
    MEDIUM = new(name: "medium")
    LARGE = new(name: "large")
    # Every round with dots sized to the screen (DotSizing): its field is
    # always about as crowded, whatever the screen, so they are one class.
    FITTED = new(name: "fitted")
    ALL = [SMALL, MEDIUM, LARGE, FITTED].freeze

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

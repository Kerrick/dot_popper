# frozen_string_literal: true

module DotPopper
  # A theme as Gameplay and Metagame knows it: its +key+, which is what is
  # saved of it and what the server names, and +opens_on+, the day from
  # which it opens to everyone once setdef has been gone for
  # Themes::GONE_DAYS, or nil for the ordinary theme and for one that waits
  # for a replacement server to release it. What it draws and plays is the
  # presentation's (Presentation::Theme), found by its key.
  class Theme < Data.define(:key, :opens_on)
    # The ordinary theme, Classic, which every player has and uses
    # without Pro.
    ORDINARY = :classic

    def initialize(key:, opens_on: nil) = super

    def ordinary? = key == ORDINARY

    # Every theme in the game, the ordinary one first, in the order the
    # Themes screen shows them.
    ALL = [
      new(key: ORDINARY),
      new(key: :ghost, opens_on: Date.new(2026, 10, 1)),
      new(key: :jack_o_lantern, opens_on: Date.new(2026, 10, 1)),
      new(key: :awake, opens_on: Date.new(2027, 10, 1)),
      new(key: :eclipse, opens_on: Date.new(2027, 10, 1)),
      new(key: :ornament, opens_on: Date.new(2026, 12, 1)),
      new(key: :santa, opens_on: Date.new(2026, 12, 1)),
      new(key: :snowman, opens_on: Date.new(2026, 12, 1)),
      new(key: :peppermint, opens_on: Date.new(2026, 12, 1)),
      new(key: :gingerbread, opens_on: Date.new(2026, 12, 1)),
      new(key: :pumpkin_pie, opens_on: Date.new(2026, 11, 1)),
      new(key: :turkey, opens_on: Date.new(2026, 11, 1))
    ].freeze
  end
end

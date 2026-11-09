# frozen_string_literal: true

module DotPopper
  # How big a game's dots are, which the player chooses on the title.
  # With SIZED_TO_SCREEN, dots sized to the screen and the DEFAULT, each
  # game's radius is DotSize.fitted to its screen, so every screen has
  # about the same room in radii, and games compare across devices.
  # STANDARD, the standard dot size, is the spec's fixed radius: DotSize's
  # on every screen, so a small screen crowds sooner and plays harder.
  # Either way the radius is set when a game starts and kept until it
  # ends, and speeds stay in radii per second. A save file still writes
  # STANDARD as "same", its name from before it was called standard.
  class DotSizing < Data.define(:name)
    def initialize(name:) = super(name: -name)

    STANDARD = new(name: "same")
    SIZED_TO_SCREEN = new(name: "fitted")

    # What a player who never chose gets (the maintainer's call after the
    # iPhone playtest).
    DEFAULT = SIZED_TO_SCREEN

    # The choice a save file holds, or DEFAULT for any other text. The
    # file is written only when the player picks a size, so "same" is
    # always a choice the player made, and is kept.
    def self.parse(text) = [STANDARD, SIZED_TO_SCREEN].find { it.name == text.to_s.strip } || DEFAULT

    def sized_to_screen? = self == SIZED_TO_SCREEN

    # The other choice.
    def toggled = sized_to_screen? ? STANDARD : SIZED_TO_SCREEN

    # The field a game starts on, given the +screen+ as a Field at the
    # usual dot size.
    def fit(screen)
      return screen unless sized_to_screen?

      Field.new(screen.width, screen.height, DotSize.fitted(screen.width, screen.height).radius)
    end

    # The class of screen a game on +screen+ counts among.
    def size_class(screen) = sized_to_screen? ? SizeClass::FITTED : SizeClass.of(screen)

    def to_text = name
  end
end

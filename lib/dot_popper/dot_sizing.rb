# frozen_string_literal: true

module DotPopper
  # How big a game's dots are, which the player chooses on Home.
  # With SIZED_TO_SCREEN, dots sized to the screen and the DEFAULT, each
  # game's radius is DotSize.fitted to its screen, so every screen has
  # about the same room in radii. That narrows the difference between
  # screens, but scores still differ with screen size and input.
  # STANDARD, the standard dot size, is the spec's fixed radius: DotSize's
  # on every screen, so a small screen crowds sooner and plays harder.
  # Either way the radius is set when a game starts and kept until it
  # ends, and speeds stay in radii per second. A save file from before
  # it was called standard says "same" (EARLIER_NAMES), which is read as
  # STANDARD.
  class DotSizing < Data.define(:name)
    def initialize(name:) = super(name: -name)

    STANDARD = new(name: "standard")
    SIZED_TO_SCREEN = new(name: "fitted")
    # Names a save file once held, and the choice each is.
    EARLIER_NAMES = { "same" => STANDARD }.freeze

    # What a player who never chose gets (the maintainer's call after the
    # iPhone playtest).
    DEFAULT = SIZED_TO_SCREEN

    # The choice a save file holds, or DEFAULT for any other text. The
    # file is written only when the player picks a size, so "standard" is
    # always a choice the player made, and is kept.
    def self.parse(text)
      name = text.to_s.strip
      [STANDARD, SIZED_TO_SCREEN].find { it.name == name } || EARLIER_NAMES.fetch(name, DEFAULT)
    end

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

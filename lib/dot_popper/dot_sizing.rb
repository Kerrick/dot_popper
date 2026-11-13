# frozen_string_literal: true

module DotPopper
  # How big a game's dots are, which the player chooses in Settings.
  # With STANDARD, the DEFAULT and "Standard" on screen, each game's
  # radius is DotSize.standard for its screen, so every screen has
  # about the same room in radii. That narrows the difference between
  # screens, but scores still differ with screen size and input.
  # BIGGER_OR_SMALLER is the spec's radius, DotSize's on every screen, so
  # a small screen crowds sooner and plays harder; Settings names it
  # "Bigger" or "Smaller", by what it does on the device, and the code
  # says both where it does not know the device. Either way the
  # radius is set when a game starts and kept until it ends, and speeds
  # stay in radii per second.
  class DotSizing < Data.define(:name)
    def initialize(name:) = super(name: -name)

    # +name+ is what dot_size.txt holds, and never changes: builds in
    # players' hands wrote "fitted" for the default and "standard" for the
    # bigger or smaller size, from when the screens called it standard,
    # and newer builds read and write the same bytes. "same", its name
    # before that, is read too (EARLIER_NAMES).
    BIGGER_OR_SMALLER = new(name: "standard")
    STANDARD = new(name: "fitted")
    # BIGGER_OR_SMALLER's old name, until no commit uses it.
    FIXED = BIGGER_OR_SMALLER
    # Names a save file once held, and the choice each is.
    EARLIER_NAMES = { "same" => BIGGER_OR_SMALLER }.freeze

    # What a player who never chose gets (the maintainer's call after the
    # iPhone playtest).
    DEFAULT = STANDARD

    # The choice a save file holds, or DEFAULT for any other text. The
    # file is written only when the player picks a size, so "standard",
    # the bigger or smaller size, is always a choice the player made, and
    # is kept.
    def self.parse(text)
      name = text.to_s.strip
      [BIGGER_OR_SMALLER, STANDARD].find { it.name == name } || EARLIER_NAMES.fetch(name, DEFAULT)
    end

    def standard? = self == STANDARD

    # The other choice.
    def toggled = standard? ? BIGGER_OR_SMALLER : STANDARD

    # The field a game starts on, given the +screen+ as a Field at the
    # usual dot size.
    def fit(screen)
      return screen unless standard?

      Field.new(screen.width, screen.height, DotSize.standard(screen.width, screen.height).radius)
    end

    # The class of screen a game on +screen+ counts among.
    def size_class(screen) = standard? ? SizeClass::STANDARD : SizeClass.of(screen)

    def to_text = name
  end
end

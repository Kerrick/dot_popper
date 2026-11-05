# frozen_string_literal: true

module DotPopper
  # How big a round's dots are, which the player chooses on the title.
  # STANDARD, the standard dot size, is the spec's rule: the radius is
  # DotSize's on every screen, so a small screen crowds sooner and plays
  # harder. With SIZED_TO_SCREEN, dots sized to the screen, each round's
  # radius is DotSize.fitted to its screen, so every screen has about the
  # same room in radii, and rounds compare across devices. Either way the
  # radius is set when a round starts and kept until it ends, and speeds
  # stay in radii per second. A save file still writes STANDARD as
  # "same", its name from before it was called standard.
  class DotSizing < Data.define(:name)
    def initialize(name:) = super(name: -name)

    STANDARD = new(name: "same")
    SIZED_TO_SCREEN = new(name: "fitted")

    # The choice a save file holds, or STANDARD for any other text.
    def self.parse(text) = text.to_s.strip == SIZED_TO_SCREEN.name ? SIZED_TO_SCREEN : STANDARD

    def sized_to_screen? = self == SIZED_TO_SCREEN

    # The other choice.
    def toggled = sized_to_screen? ? STANDARD : SIZED_TO_SCREEN

    # The field a round starts on, given the +screen+ as a Field at the
    # usual dot size.
    def fit(screen)
      return screen unless sized_to_screen?

      Field.new(screen.width, screen.height, DotSize.fitted(screen.width, screen.height).radius)
    end

    # The class of screen a round on +screen+ counts among.
    def size_class(screen) = sized_to_screen? ? SizeClass::FITTED : SizeClass.of(screen)

    def to_text = name
  end
end

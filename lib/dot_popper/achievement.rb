# frozen_string_literal: true

module DotPopper
  # The achievements a player can earn, each for skill and none for time spent:
  # something the game asks a player to do well, done. Their numbers are
  # here, apart from the rules, which they never touch. The ids are the
  # order the Stats screen lists them in, and what Achievements saves.
  #
  # Sharpshooter's number was chosen by playing the real rules with model
  # players (doc/design/progress.md): a player who taps only once a fingertip
  # fits on the dot pops it with a third or more showing, so a dot popped
  # with under a tenth showing was a deliberate, precise tap.
  module Achievement
    IDS = %i[sharpshooter sharp_trio patience blink steady unshaken shake_off comeback fast_start big_score
             long_haul].freeze

    SHARP = 0.10 # a pop with less than this share of the dot showing is sharp (Visibility)
    SHARP_TRIO = 3 # dots popped sharply in one game
    SHARP_TRIO_BELOW = 0.25 # a pop in a trio only needs this little of the dot showing
    PATIENCE = 3.0 # seconds waited for a dot that spawned covered, tapping nothing, before popping it
    BLINK = 0.4 # a dot popped within this many seconds of the pop before it
    STEADY = 20 # dots in a row without a mistake
    UNSHAKEN = 40
    SHAKE_OFF = 10 # dots in a row after a mistake
    BRINK = 2.0 # seconds left on the clock, to come back from...
    BACK = 10.0 # ...to this many
    FAST_START = 15 # dots popped in a game's first FAST_START_SECONDS
    FAST_START_SECONDS = 10.0
    BIG_SCORE = 75
    LONG_HAUL = 90.0 # seconds a game lasts

    def self.known?(id) = IDS.include?(id)
  end
end

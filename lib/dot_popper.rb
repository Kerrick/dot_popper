# frozen_string_literal: true

# The rules of Dot Popper: dots, scoring, the clock, and the flow from
# title to game over. Nothing here draws, plays sounds, or reads input, so
# all of it runs, and is tested, without a window.
module DotPopper
end

require_relative "dot_popper/rules"
require_relative "dot_popper/events"
require_relative "dot_popper/field"
require_relative "dot_popper/dot_size"
require_relative "dot_popper/dot"
require_relative "dot_popper/countdown"
require_relative "dot_popper/stack"
require_relative "dot_popper/round"
require_relative "dot_popper/best_score"
require_relative "dot_popper/round_stats"
require_relative "dot_popper/playtest_log"
require_relative "dot_popper/game"

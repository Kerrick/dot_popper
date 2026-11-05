# frozen_string_literal: true

require_relative "presentation"

module DotPopper
  # Dot Popper on Lota: the thin layer that draws the Presentation's Show
  # in the window, plays its sounds, saves to the save folder, and turns
  # Lota's callbacks into taps. Everything that can be decided without
  # Lota is decided in Presentation; this layer only carries it out.
  module Shell
  end
end

%w[save_file clipboard speaker haptics font_book pen dot_painter effects_painter hud_painter hint_painter mute_button
   pill_button check lettering title_painter records_painter finale_painter tilt_hint_painter cursor_painter gamepads pile
   accelerometer tilting sparks bloom renderer app].each { require_relative "shell/#{it}" }

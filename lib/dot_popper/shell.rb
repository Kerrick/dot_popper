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

%w[save_file clipboard desktop_window url_opener speaker haptics font_book font_measure pen dot_painter effects_painter hud_painter mute_button
   tally_painter pill_button window_buttons_painter primary_button segmented_painter scrim_painter check lettering title_painter records_painter credits_painter notice_files share_button share_preview_painter finale_painter cursor_painter splash_painter skip_button hand_sprites ghost_painter tutorial_painter gamepads pile
   accelerometer tilting dragging sparks bloom renderer vulkan_rescue app].each { require_relative "shell/#{it}" }

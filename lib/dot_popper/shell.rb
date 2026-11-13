# frozen_string_literal: true

require_relative "presentation"
require_relative "composition/root"

module DotPopper
  # Dot Popper on Lota: the thin layer that draws the Presentation's Show
  # in the window, plays its sounds, saves to the save folder, and turns
  # Lota's callbacks into taps. Everything that can be decided without
  # Lota is decided in Presentation; this layer only carries it out.
  module Shell
  end
end

%w[platforms save_file store_answers store_helper clipboard desktop_window url_opener speaker haptics font_book font_measure pen glyphs dot_painter effects_painter hud_painter mute_button
   tally_painter pill_button window_buttons_painter primary_button segmented_painter scrim_painter check_mark lettering code_box member_icon_painter group_painter settings_painter achievements_painter privacy_painter server_painter home_painter stats_painter offer_painter themes_painter credits_painter notice_files share_button share_preview_painter game_over_painter cursor_painter splash_painter hand_sprites ghost_painter tutorial_painter lota_input gamepads pile
   accelerometer tilting dragging sparks bloom scene arrival_painter themed_name renderer vulkan_rescue engine development_hooks app].each { require_relative "shell/#{it}" }

# frozen_string_literal: true

require_relative "../dot_popper"

module DotPopper
  # How Dot Popper looks, sounds, and answers a tap, apart from Lota: the
  # settings (Style), easing and tweens, each dot's animation, the effects
  # that follow a tap, the HUD's numbers, layout, input routing, the sound
  # synthesizer, and the Show that ties them to the rules' events. None of
  # it draws or plays anything, so all of it runs, and is tested, without
  # a window; DotPopper::Shell draws and plays it with Lota.
  module Presentation
  end
end

%w[
  reveal tutor clipboard window_control scrim
  color ease tween pixels palette theme themes/ghost themes/jack_o_lantern themes/awake themes/eclipse themes/ornament themes/santa themes/snowman themes/peppermint themes/jingle_bell themes/gingerbread themes/pumpkin_pie themes/turkey scenery theme_keeper theme_feed arrival input_kind words achievement_words tally layout column measure home_plan game_over_plan share_preview sheet_sharing storefront fake_store website_store server_choice offer_plan share_plan particles rings floaters shake edge_flash effects
  dot_animations dot_style hud synth stereo haptics input_router pile_grab fake_drag gamepad_cursor gamepad_buttons sizing_preview attract marquee game_over stats themes credits hold_to_confirm pill_fill pile tilt bloom autopilot shot_schedule frame_clock frame_meter slow_frame screen_report mouse_travel chatter hover splash level anchor spotlight flight ghost_hand pointing_hand tutorial tutorial_flag renderer_choice vulkan_failure relaunch member_icon names code_pad group_notice group_panel group_screen pages style show
].each { require_relative "presentation/#{it}" }

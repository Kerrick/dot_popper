# frozen_string_literal: true

require_relative "../dot_popper"

module DotPopper
  # How Dot Popper looks, sounds, and answers a tap, apart from Lota: the
  # settings (Look), easing and tweens, each dot's animation, the effects
  # that follow a tap, the HUD's numbers, layout, input routing, the sound
  # synthesizer, and the Show that ties them to the rules' events. None of
  # it draws or plays anything, so all of it runs, and is tested, without
  # a window; DotPopper::Shell draws and plays it with Lota.
  module Presentation
  end
end

%w[
  reveal tutor clipboard window_control scrim
  color ease tween pixels palette theme wardrobe input_kind words feat_words tally layout column measure title_plan finale_plan share_preview sheet_sharing share_plan particles rings floaters shake edge_flash effects
  dot_animations dot_look hud synth stereo haptics input_router pile_grab fake_drag gamepad_cursor gamepad_buttons sizing_preview attract marquee finale records looks credits hold_to_confirm pill_fill pile tilt bloom autopilot shot_schedule frame_clock frame_meter slow_frame screen_report mouse_travel chatter hover splash level anchor spotlight flight ghost_hand pointing_hand tutorial tutorial_flag renderer_choice vulkan_failure relaunch group_panel group_screen look show
].each { require_relative "presentation/#{it}" }

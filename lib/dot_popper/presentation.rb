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
  reveal tutor
  color ease tween pixels palette words layout particles rings floaters shake edge_flash effects
  dot_animations hud synth stereo haptics input_router attract marquee finale pile bloom autopilot shot_schedule look show
].each { require_relative "presentation/#{it}" }

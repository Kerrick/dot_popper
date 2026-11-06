# frozen_string_literal: true

# Lota reads this before it opens the window. main.rb then sizes the
# window to the play area DotPopper::Presentation::Look::WINDOW names,
# fitted to the desktop.
def Lota.conf(t)
  # The save folder's name. DOT_POPPER_SAVE_AS gives a test run a folder
  # of its own, so it starts from nothing and leaves the player's alone.
  t.identity = ENV.fetch("DOT_POPPER_SAVE_AS", "dot_popper")
  t.highdpi = true # graphics units are logical pixels, so a dot is the same size on any display
  t.window.title = "Dot Popper"
  t.window.width = 1200
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth = 400
  t.window.minheight = 320
  # DOT_POPPER_RENDERERS=opengl (or vulkan, or metal, comma-separated, in
  # the order to try) chooses the graphics renderer, to compare them on a
  # device; unset, LÖVE's own order applies.
  renderers = ENV.fetch("DOT_POPPER_RENDERERS", "").split(",").map(&:strip).reject(&:empty?)
  t.renderers = renderers.map(&:to_sym) unless renderers.empty?
end

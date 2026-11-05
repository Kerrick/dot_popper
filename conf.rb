# frozen_string_literal: true

# Lota reads this before it opens the window. main.rb then sizes the
# window to the play area DotPopper::Presentation::Look::WINDOW names,
# fitted to the desktop.
def Lota.conf(t)
  t.identity = "dot_popper" # the save folder's name
  t.highdpi = true # graphics units are logical pixels, so a dot is the same size on any display
  t.window.title = "Dot Popper"
  t.window.width = 1200
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth = 400
  t.window.minheight = 320
end

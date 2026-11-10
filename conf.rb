# frozen_string_literal: true

require_relative "lib/dot_popper/build"
require_relative "lib/dot_popper/shell/vulkan_rescue"

# Lota reads this before it opens the window. main.rb then sizes the
# window to the play area DotPopper::Presentation::Look::WINDOW names,
# fitted to the desktop.
def Lota.conf(t)
  # The save folder's name. DOT_POPPER_SAVE_AS gives a test run a folder
  # of its own, so it starts from nothing and leaves the player's alone.
  t.identity = DotPopper::Build.settings(ENV).fetch("DOT_POPPER_SAVE_AS", "dot_popper")
  t.highdpi = true # graphics units are logical pixels, so a dot is the same size on any display
  t.window.title = "Dot Popper"
  t.window.width = 1200
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth = 400
  t.window.minheight = 320
  # The game draws no stencil or depth, so it asks for neither buffer. On
  # a screen whose scale isn't whole (an iPhone 13 mini at 2.88), LÖVE's
  # Metal backend sizes those buffers from the width in whole units, 811
  # by 2.88 = 2336 px, and a render pass is only as wide as its smallest
  # buffer, so the drawable's last 2 of 2338 px went undrawn in landscape.
  t.window.stencil = false
  t.window.depth = false
  # Which graphics renderers LÖVE may use (t.graphics.renderers; LÖVE 12 moved
  # it from t.renderers). It tries them in its own fixed order, Vulkan
  # first, whatever order is given here, and gives up rather than trying
  # OpenGL when a computer has Vulkan but no GPU it can use (old graphics,
  # virtual machines, remote desktops), so on Linux only OpenGL is allowed,
  # the most tested and most widely supported. Windows allows both, so x64
  # PCs get Vulkan: there, OpenGL's fullscreen hides the Xbox Game Bar's
  # overlay while it still takes the controller, and Vulkan's shows it.
  # Where Vulkan then fails to start the game, the game starts again
  # without it, and leaves it out for a month (Shell::VulkanRescue).
  # Android keeps LÖVE's order, Vulkan first, as Windows does.
  # Apple's systems have Metal alone.
  # DOT_POPPER_RENDERERS=opengl (or vulkan, or metal, comma-separated)
  # overrides this, to compare them on a device, and DOT_POPPER_NO_VULKAN=1
  # leaves Vulkan out, as after it failed.
  @vulkan_rescue = DotPopper::Shell::VulkanRescue.choose(identity: t.identity, title: t.window.title)
  @vulkan_rescue.apply(t.graphics)
end

# Vulkan's failure to start the game starts it again without Vulkan;
# anything else shows Lota's error screen.
def Lota.errorhandler(error) = @vulkan_rescue&.rescue(error) || super

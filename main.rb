# frozen_string_literal: true

# Dot Popper. The rules are in lib/dot_popper, how the game looks and
# sounds is in lib/dot_popper/presentation, and lib/dot_popper/shell
# carries that out with Lota. This file only hands Lota's callbacks to
# the game.
#
# Controls: tap or click a dot. F11, or Alt+Enter (Cmd+Enter on a Mac),
# toggles fullscreen; M toggles sound, as the speaker on the title does;
# Escape quits.
#
# Development settings, read from the environment:
#
#   DOT_POPPER_AUTOPLAY=1       a bot plays: title, a round, game over, and
#                               round again. It mostly taps fresh dots and
#                               sometimes a popped one, so penalties show.
#   DOT_POPPER_SHOTS=0.5,3,6.5  captures the screen at these seconds after
#                               start, as shot-1.png, shot-2.png, ... in the
#                               save folder, and prints each file's path.
#   DOT_POPPER_QUIT_AFTER=20    quits after this many seconds.
#   DOT_POPPER_SEED=42          makes the dots' randomness repeatable.
#   DOT_POPPER_NO_SHADERS=1    draws with plain shapes, as on a GPU whose
#                               driver will not compile the shaders.
#   DOT_POPPER_CALM=1           turns off the screen shake (reduced motion).
#                               This one is for players, too.

require_relative "lib/dot_popper/shell"

def Lota.load
  @app = DotPopper::Shell::App.new
  @app.load
end

def Lota.update(dt) = @app.update(dt)
def Lota.draw = @app.draw
def Lota.mousepressed(x, y, button, istouch) = @app.mouse_pressed(x, y, button, istouch)

def Lota.touchpressed(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app.touch_pressed(id, x, y, devicetype, mouse)
end

def Lota.keypressed(key) = @app.key_pressed(key)
def Lota.resize(_width, _height) = @app&.resize

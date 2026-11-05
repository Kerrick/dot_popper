# frozen_string_literal: true

# Dot Popper. The rules are in lib/dot_popper, how the game looks and
# sounds is in lib/dot_popper/presentation, and lib/dot_popper/shell
# carries that out with Lota. This file only hands Lota's callbacks to
# the game.
#
# Controls: tap or click a dot. F11, or Alt+Enter (Cmd+Enter on a Mac),
# toggles fullscreen; M toggles sound, as the speaker on the title does;
# Escape quits. On a gamepad (Lota 0.1.3 and newer), the left stick or
# d-pad aims, A or the right trigger presses, Start starts and continues,
# Y copies the result on Game Over, and Back toggles sound.
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
#   DOT_POPPER_WINDOW=400x850   opens the window at this size, to check a
#                               narrow screen.
#   DOT_POPPER_SAVE_AS=test     saves in a folder of this name instead, so
#                               a run starts from nothing.
#   DOT_POPPER_CALM=1           turns off the screen shake, and lets the
#                               game-over pile settle softly (reduced
#                               motion). This one is for players, too.

require_relative "lib/dot_popper/shell"

def Lota.load
  @app = DotPopper::Shell::App.new
  @app.load
end

def Lota.update(dt) = @app.update(dt)
def Lota.draw = @app.draw
def Lota.mousepressed(x, y, button, istouch) = @app.mouse_pressed(x, y, button, istouch)
def Lota.mousemoved(x, y, _dx, _dy, _istouch) = @app&.mouse_moved(x, y)

def Lota.touchpressed(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app.touch_pressed(id, x, y, devicetype, mouse)
end

def Lota.keypressed(key) = @app.key_pressed(key)
def Lota.resize(_width, _height) = @app&.resize

# Gamepads. Lota 0.1.2 binds no controllers and never calls these; from
# 0.1.3, Lota passes the Joystick first, as LÖVE does.
def Lota.gamepadpressed(_joystick, button) = @app&.gamepad_pressed(button)
def Lota.gamepadaxis(_joystick, axis, value) = @app&.gamepad_axis(axis, value)
def Lota.joystickadded(joystick) = @app&.gamepad_added(joystick)
def Lota.joystickremoved(joystick) = @app&.gamepad_removed(joystick)

# frozen_string_literal: true

# Dot Popper. The rules are in lib/dot_popper, how the game looks and
# sounds is in lib/dot_popper/presentation, and lib/dot_popper/shell
# carries that out with Lota. This file only hands Lota's callbacks to
# the game.
#
# Controls: tap or click a dot. F11, or Alt+Enter (Cmd+Enter on a Mac),
# toggles fullscreen; M toggles sound, as the speaker on Home does;
# Escape quits. On a gamepad (Lota 0.1.3 and newer), the left stick or
# d-pad aims, A or the right trigger presses, Start starts and continues,
# Y copies the result on Game Over (and, held on the Stats screen,
# clears Stats, which a press of Y then undoes), X opens the
# Stats screen from Home, B (or Start) leaves it, either
# shoulder button switches the dot size on Home, and Back toggles
# sound. On Game Over the right
# stick, or tilting a tablet, rolls the pile of dots about, and a shake
# throws them; a mouse, a finger, or A held on a dot drags it about and
# throws it, and a click, tap, or press of A that drags nothing goes back
# to Home as it is let go. The words on screen say "tap", "click",
# or name the button, after whatever the player last pressed with.
#
# Development settings, read from the environment (a test build has more
# of its own, listed in lib/dot_popper/test_build/core.rb):
#
#   DOT_POPPER_AUTOPLAY=1       a bot plays: Home, a game, Game Over, and
#                               game again. It mostly taps bright dots and
#                               sometimes a popped one, so penalties show.
#   DOT_POPPER_NO_SPLASH=1      leaves out setdef's splash before Home
#   DOT_POPPER_SERVER=http://localhost:9292
#                               asks this server for friend groups and themes
#                               instead of Network::Server::SERVER_URL
#                               (empty: none).
#   DOT_POPPER_GROUP_SCREEN=1   opens the Friend group screen at launch,
#                               to check how it looks.
#   DOT_POPPER_NO_TUTORIAL=1    never opens the tutorial on a first Play (the
#                               bot and the GUI suite leave it out too)
#   DOT_POPPER_TUTORIAL=1       opens the tutorial on every Play, seen or not
#                               (the bot and the GUI suite do too).
#   DOT_POPPER_SHOTS=0.5,3,6.5  captures the screen at these seconds after
#                               start, as shot-1.png, shot-2.png, ... in the
#                               save folder, and prints each file's path.
#   DOT_POPPER_QUIT_AFTER=20    quits after this many seconds.
#   DOT_POPPER_SEED=42          makes the dots' randomness repeatable.
#   DOT_POPPER_PERF=1           prints frames a second and the longest
#                               frame every five seconds.
#   DOT_POPPER_NO_SHADERS=1    draws with plain shapes, as on a GPU whose
#                               driver will not compile the shaders.
#   DOT_POPPER_WINDOW=400x850   opens the window at this size, to check a
#                               narrow screen.
#   DOT_POPPER_SAVE_AS=test     saves in a folder of this name instead, so
#                               a run starts from nothing.
#   DOT_POPPER_FAKE_TILT=0.6,0  stands in for an accelerometer that reads
#                               this x,y, in g, in the device's portrait
#                               axes, so the game-over pile rolls as on a
#                               tilted tablet: 0.6,0 rolls it to the left.
#   DOT_POPPER_FAKE_DRAG=0.5,0.9,0.3,0.3
#                               on each Game Over, takes the dot nearest the
#                               first point (fractions of the window's
#                               width and height), drags it to the second
#                               over a second, and throws it there.
#   DOT_POPPER_FAKE_GAMEPAD=1   plays as if a gamepad were in hand: the
#                               words name its buttons and its cursor
#                               shows, and DOT_POPPER_FAKE_DRAG's drag is
#                               made with the cursor and A.
#   DOT_POPPER_CALM=1           turns off the screen shake, and lets the
#                               game-over pile settle softly and turn
#                               slowly when tilted, never thrown by a
#                               shake (reduced motion). This one is for
#                               players, too.
#   DOT_POPPER_SCENARIO=game   plays one of rake test:gui's scripted
#                               sessions, through the callbacks below,
#                               checks it as it goes, and quits with 0
#                               only if every check passed
#                               (test/gui/scenario_runner.rb).

require_relative "lib/dot_popper/shell"

def Lota.load
  @app = DotPopper::Shell::App.new
  @app.load
end

def Lota.update(dt) = @app.tick(dt)
def Lota.draw = @app.draw
def Lota.mousepressed(x, y, button, istouch) = @app.mouse_pressed(x, y, button, istouch)
def Lota.mousemoved(x, y, _dx, _dy, istouch) = @app&.mouse_moved(x, y, istouch)
def Lota.mousereleased(x, y, button, istouch, _presses) = @app&.mouse_released(x, y, button, istouch)

def Lota.touchpressed(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app.touch_pressed(id, x, y, devicetype, mouse)
end

def Lota.touchmoved(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app&.touch_moved(id, x, y, devicetype, mouse)
end

def Lota.touchreleased(id, x, y, _dx, _dy, _pressure, devicetype, mouse)
  @app&.touch_released(id, x, y, devicetype, mouse)
end

def Lota.focus(focused) = @app&.focus(focused)
def Lota.mousefocus(focused) = @app&.mouse_focus(focused)

def Lota.wheelmoved(_x, y, *) = @app&.wheel_moved(y)
def Lota.keypressed(key) = @app.key_pressed(key)
def Lota.resize(_width, _height) = @app&.resize

# Gamepads, from Lota 0.1.3. Lota passes the Joystick first, as LÖVE
# does.
def Lota.gamepadpressed(_joystick, button) = @app&.gamepad_pressed(button)
def Lota.gamepadreleased(_joystick, button) = @app&.gamepad_released(button)
def Lota.gamepadaxis(_joystick, axis, value) = @app&.gamepad_axis(axis, value)
def Lota.joystickadded(joystick) = @app&.gamepad_added(joystick)
def Lota.joystickremoved(joystick) = @app&.gamepad_removed(joystick)

require_relative "test/gui/scenario_runner" unless DotPopper::Build.settings(ENV).fetch("DOT_POPPER_SCENARIO", "").empty?

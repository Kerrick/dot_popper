# Why Ruby

Dot Popper is the kind of game people write in LÖVE: a window, some
circles, a clock. LÖVE games are written in Lua, and Lota runs the same
engine under Ruby. So the fair question is what Ruby buys a game like this
one, and what it costs. This essay answers with the game's own code,
next to the Lua a LÖVE programmer would write for the same job. The Lua is
idiomatic, not a straw man; most of it is the shape of LÖVE's own
tutorials.

## A dot is a value

Here is a dot, from `lib/dot_popper/dot.rb`:

```ruby
class Dot < Data.define(:id, :x, :y, :velocity_x, :velocity_y, :radius, :popped)
  def pop = with(popped: true)

  def covers?(point_x, point_y)
    ((point_x - x)**2) + ((point_y - y)**2) <= radius**2
  end
end
```

And here is the Lua:

```lua
local dot = { id = 1, x = 400, y = 300, vx = 120, vy = -60, popped = false }

function pop(dot) dot.popped = true end
```

The Lua dot is a bag of fields that anything may change. The Ruby dot
cannot change at all: it has no setters, and the object is frozen. Popping it gives a new dot with the same `id`. That sounds
like a cost, and in the inner loop it is one (see the last section), but it
pays three ways.

First, equality. Two Ruby dots with the same fields are `==`, so a test
says `assert_equal before, after` about a whole stack of dots. Two Lua
tables are equal only if they are the same table (short of writing an
`__eq` metamethod), and every Lua test suite
grows a `deep_equal` helper.

Second, `with`. A tap that pops a dot must change the dot, the score, and
the clock together. Because each is a value, `Game#pop` builds the new
ones and swaps them in; nothing is ever half-changed.

Third, pattern matching. The fuzz test takes apart each event by shape:

```ruby
case event
in DotPopper::Events::Missed
  assert_nil top, "#{where}: a tap on a dot missed"
in DotPopper::Events::Popped(dot:, spawned:)
  assert_equal top&.id, dot.id, "#{where}: a pop reached past the top dot"
  # ...and that the stack gained exactly +spawned+, at the bottom
in DotPopper::Events::Penalized(dot:)
  assert top.popped?, "#{where}: a fresh dot cost a penalty"
end
```

Lua has no equivalent. The closest is `if event.kind == "popped" then`,
with a string that nothing checks.

## The state pattern, as values

The game is Title, then Playing, then Game Over. In Ruby each state is a
small value that answers `press` and `update` with the state that comes
next:

```ruby
class Title < Data.define
  def press(game, _x, _y) = game.start_round
  def update(_game, _seconds) = self
end

class Playing < Data.define(:game, :seed)
  def update(game, seconds)
    game.update(seconds)
    settle(game)
  end
end
```

The usual LÖVE version keeps a string and asks about it in every callback:

```lua
function love.mousepressed(x, y)
  if state == "title" then start_round()
  elseif state == "playing" then tap(x, y)
  elseif state == "gameover" and shown > 0.9 then state = "title" end
end
```

Each callback holds a piece of every state, so adding a state means
editing every callback. In Ruby a state's rules sit in one class, and a
state that does not handle a message fails loudly. Lua can do the state
pattern with metatables, and good Lua programmers do; Ruby makes it the
short way rather than the disciplined way.

## Blocks and Enumerable

The core rule of the game, that a tap reaches only the topmost dot, is one
line in `Stack`:

```ruby
def top_at(x, y) = dots.find { |dot| dot.covers?(x, y) }
```

In Lua:

```lua
function top_at(dots, x, y)
  for _, dot in ipairs(dots) do
    if covers(dot, x, y) then return dot end
  end
  return nil
end
```

The Lua is fine. But a LÖVE game's rules are full of loops like it, and
the reader must check each one for an off-by-one or a missing `return nil`.
`Stack` defines `each` once, includes `Enumerable`, and gets `find`,
`count`, `map`, `select`, and the rest. Drawing bottom-up is
`dots.reverse_each`, not `for i = #dots, 1, -1`. Moving every dot is
`dots.map_dots { it.move(seconds, field) }`.

## Keyword arguments

```ruby
Events::Popped.new(dot: popped, x:, y:, points: Rules::POP_POINTS, seconds: Rules::POP_SECONDS, spawned:)
```

Every argument is named, `x:` is short for `x: x`, and a misspelled or
missing one is an `ArgumentError` at the call. The Lua habit is an options
table, `{ dot = popped, x = x, y = y, ... }`, where a misspelled key is
silently `nil` until something far away does arithmetic on it.

## Testing the rules without a window

Nothing in `lib/dot_popper/*.rb` mentions Lota. The rules take a field, a
`Random`, and taps, and report events; drawing and sound listen. So the
tests are plain minitest, and CI runs them on an Ubuntu machine with no
screen:

```ruby
def test_popping_a_fresh_dot_scores_a_point_adds_a_second_and_spawns_a_dot_underneath
  target = dot(400, 300)
  game = round_with(target)

  event = game.tap_at(410, 290)

  assert_instance_of Events::Popped, event
  assert_equal 1, game.score
  # ...
end
```

The fuzz test goes further. It plays 2,000 random games on random fields,
from a sliver narrower than a dot to a large monitor. After every tap and
tick it checks the invariants: dots stay on the field, the score never
drops below zero, exactly one dot is fresh, and a tap reaches only the top
dot. That is over half a million assertions in under a second. Reverse the
order `top_at` searches in, and it fails on the tenth game.

None of this is impossible in Lua; busted, a popular Lua test framework, is a good one. But LÖVE
code tends to call `love.graphics` from the same functions that keep score,
and then a test needs a fake `love` table first. Ruby's culture of small
objects and fast tests makes the separation the normal way to work.

## Types: RBS and Steep

Every class in the rules has a signature in `sig/`, with no `untyped`:

```rbs
class Stack < ::Data
  include Enumerable[Dot]

  def top_at: (number x, number y) -> Dot?

  def map_dots: () { (Dot) -> Dot } -> Stack
end
```

`bundle exec rake` runs Steep over the rules in strict mode. Writing the
signatures found two real loose ends. A `Field` kept whatever numbers it
was given, so an integer radius could reach a dot's position through
`confine`. And `Game#subscribe` called with no listener stored `nil`, which
only failed on the next event. Plain Lua tables have no such check; a
mistyped field name is a new field. To be fair, Lua has typed dialects
(Luau, Teal) and LuaLS annotations, but none is part of LÖVE's normal
toolchain.

Steep has limits too. Version 2.1 does not check `case`/`in` at all; it
treats a pattern-matching branch as untyped and says so only at a level
that is silent by default. So the Steepfile makes that an error, and the
typed core uses `if` where it would rather use `in`.

## Ractors

`script/simulate.rb` plays the rules with a model player on six screen
sizes. Each size runs in its own Ractor, Ruby's unit of parallel execution:

```ruby
DEVICES.map { |device| Ractor.new(device, games) { |each, count| Simulation.play(each, count) } }.map(&:value)
```

That works because the rules are frozen values. A Ractor may read a frozen
`Data` value from any other Ractor without copying it, so the device list
and the rule numbers are shared, and each Ractor makes its own `Random`.
One value was not shareable: `DotSize` held a string built at run time.
Freezing it was the whole fix, and a test keeps every value shareable.

Lua itself runs one thread per interpreter. LÖVE's `love.thread` starts
more interpreters and passes messages between them through channels, which
copy every table. There is no way to hand another thread a structure and
promise it will never change.

The speedup was smaller than the story suggests. With Ruby's default heap,
the Ractors ran no faster than one loop. A game makes new dots every step,
and Ruby 4.0 stops every Ractor for each garbage collection: about 1,100 of
them in a short run. Starting Ruby with a larger heap cut that to about 25,
and the six devices then ran 2.0 times as fast on a busy ten-core Mac
(1.2 to 2.2 times across the night's runs, as other work came and went).

## Small things

The rest is texture, but it adds up. Endless methods make one-line rules
read as definitions:

```ruby
def expired? = remaining <= 0
def tick(seconds) = adjust(-seconds)
```

`it` names a block's single argument without ceremony, as in
`dots.map_dots { it.confine(field) }`. The
`# frozen_string_literal: true` comment makes every string literal in a
file immutable. In fairness, every Lua
string already is.

## Where Lua wins

**Speed.** Moving thirty dots 100,000 times, bounce and all, takes this
game's Ruby 4.4 seconds (3.4 with YJIT). The same loop in Lua 5.4,
mutating tables in place, takes 0.58 seconds, and LuaJIT 0.012. Part of
that is Ruby, and part is the immutable design, which makes a new dot
every step. For Dot Popper it does not matter: a frame of thirty dots
costs Ruby about 44 microseconds of a 16,667-microsecond frame. For a
game with ten thousand bullets it would.

**Size.** LuaJIT is a 515 KB library, made to be embedded in a C
program with a few calls. Ruby's static library alone is 27 MB on this
Mac, and a packaged Ruby game carries that runtime and its standard
library on top of the same engine LÖVE ships.

**Reach.** LÖVE ships builds for Android and iOS, and community ports
such as love.js run it in a browser. Lota's released gems are for macOS,
Windows, and Linux. Its iOS engine is experimental, and this game's iPad
build has so far run only in the Simulator. If the game must be on a
phone this month, that settles it.

**Ecosystem.** LÖVE has nearly two decades of libraries (bump, hump, anim8,
STI), tutorials, and game-jam code to borrow. Lota has its docs and this
game.

**Startup.** On this Mac, `lua -e ''` starts in a few milliseconds;
`ruby -e 0`, with RubyGems, in about fifty.

## The trade

Lua wins on what the runtime itself brings: speed per object,
size on disk, the platforms it reaches, and the code already written for
it. Ruby wins in the rules, the part of a game that has to be right, that
changes most during design, and that is worth testing thousands of times
a second. Dot Popper's rules are about seven hundred lines, mostly frozen
values, all tested without a window and type-checked, and their values
are safe to share across cores. The drawing, where raw speed matters, is LÖVE's C++ engine
either way.

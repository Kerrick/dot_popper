# frozen_string_literal: true

module DotPopperGui
  # The tutorial a first Play opens, played through as a new player would,
  # with one tap too soon on the popped dot, and each beat's freeze kept
  # as a screenshot. The director leaves the tutorial out of every other
  # session, so this one forces it (DOT_POPPER_TUTORIAL=1). The game stays
  # on its title until its end, and then the game goes on from its dots,
  # its score and its time, with only the clock starting. Its wrong taps,
  # the guide's and the player's, cost what they do in play.
  #
  # It plays with the mouse, or with DOT_POPPER_GUI_INPUT=touch, a finger.
  # With DOT_POPPER_GUI_INPUT=gamepad, it opens the tutorial with Start,
  # keeps the first beat's screenshot, and skips it with B, since only a
  # real stick moves the cursor.
  class TutorialScenario < Scenario
    scenario :tutorial

    T = DotPopper::Presentation::Tutorial
    R = DotPopper::Rules

    def play
      return by_gamepad if hand == "gamepad"

      open_tutorial(how)
      tap_the_bright_dot
      points_and_time
      wait_for_the_bright_dot
      wait_for("the last pop's numbers", within: 120) { shown == [1, 8] }
      check_equal([true, false], tutorial.dots.map(&:popped?), "it bursts still bright as its numbers land")
      the_dots_in_a_row
      now_it_runs
      check_equal("seen", File.read(saved("tutorial.txt")).strip, "tutorial.txt remembers it was seen")
      run_out_the_clock
      continue_to_title
    end

    private

    def hand = ENV.fetch("DOT_POPPER_GUI_INPUT", "mouse")
    def how = method(hand == "touch" ? :touch : :click)
    def tutorial = show.tutorial
    def dot(id) = tutorial.dots.find { it.id == id }
    def shown = [tutorial.hud.score, tutorial.hud.seconds]
    def name(beat) = "tutorial-#{hand}-#{layout.width.round}x#{layout.height.round}-#{beat}"

    def open_tutorial(how)
      check(show.title?, "the game opens on the title")
      wait(0.5)
      play = show.play_reach
      how.call(play.center_x, play.center_y)
      check(show.tutorial?, "the first Play opens the tutorial")
      check(cabinet.state.is_a?(DotPopper::Cabinet::Title) && cabinet.game.nil?, "the game stays on its title meanwhile")
    end

    def by_gamepad
      check_equal(DotPopper::Presentation::InputKind::GAMEPAD, show.input, "a gamepad is in hand")
      open_tutorial(->(*) { pad(:start) })
      freeze_on(:aim)
      wait(0.6)
      keep_screenshot(name("1-tap"))
      pad(:b)
      check(show.playing?, "a gamepad's B skips it, and the game starts at once")
    end

    # Waits for the beat that freezes time, and for it to settle.
    def freeze_on(beat)
      wait_for("the tutorial's #{beat} beat", within: 900) { tutorial&.beat == beat }
      wait(DotPopper::Presentation::Look::TUTORIAL.stop + 0.05)
      check(tutorial.rate.zero?, "time stands still in the #{beat} beat")
    end

    def tap_the_bright_dot
      freeze_on(:aim)
      wait_for("the guide pressing", within: 200) { tutorial.ghost_pose&.press.to_f > 0.9 }
      keep_screenshot(name("1-tap"))
      shot = screenshot
      bright = dot(T::BRIGHT)
      # Left of its middle, clear of the hand: the emoji's finger reaches
      # about 0.2 of a radius left of the point it taps, its thumb only
      # below the dot, and the tap's ripple has spread past 0.8 by
      # the time the press is down, so a small dot on a 1x screen needs
      # more than half a radius; the dot's pale ring starts past 0.65.
      x = bright.x - (bright.radius * 0.55)
      y = bright.y
      check(shot.fresh?(x, y), "the bright dot shows under the spotlight (#{shot.describe(x, y)})")
      corner = shot.lightness(layout.width * 0.1, layout.height * 0.9)
      check(corner < shot.lightness(x, y) * 0.3, "everything but the bright dot dims")
      how.call(bright.x, bright.y)
      check_equal(:points, tutorial.beat, "a tap on the bright dot pops it")
      check(dot(T::BRIGHT).fresh? && dot(T::NEXT).nil?, "it bursts still bright, with nothing under it yet")
    end

    def points_and_time
      wait(0.1)
      keep_screenshot(name("2-burst"))
      wait(0.35)
      keep_screenshot(name("2-points"))
      wait_for("the point to land", within: 120) { shown == [1, 10] }
      check_equal([1, 10], shown, "the point lands in the score")
      wait_for("the second to land", within: 120) { shown == [1, 11] }
      wait(0.3)
      keep_screenshot(name("2-time"))
      check_equal([1, 11], shown, "the stopwatch lands in the time")
      check(cabinet.game.nil?, "nothing is scored for real")
      wait_for("time to flow again", within: 120) { tutorial.beat == :peek }
      check(dot(T::BRIGHT).popped? && dot(T::NEXT)&.fresh?, "as it does, the dot is popped, and one born under it")
      wait(0.3)
      keep_screenshot(name("2-popped"))
    end

    def wait_for_the_bright_dot
      freeze_on(:warn)
      wait_for("the guide's tap on the popped dot", within: 200) { tutorial.flights.any? }
      check_equal([0, 9], shown, "the guide's tap costs the point there was and two seconds")
      wait(0.2)
      keep_screenshot(name("3-cost"))
      wag = tutorial.ghost.look.wag
      wait_for("the guide's finger-wag", within: 300) { tutorial.ghost_pose&.turn.to_f.abs > wag.angle * 0.8 }
      keep_screenshot(name("3-wag"))
      too_soon
      wait_for("the bright dot clear", within: 900) { tutorial.beat == :aim_next }
      wait(0.7)
      keep_screenshot(name("3-clear"))
      bright = dot(T::NEXT)
      how.call(bright.x, bright.y)
      check_equal(:runs, tutorial.beat, "a tap on the clear bright dot pops it")
    end

    # A tap on the popped dot, on its side away from the bright one: its
    # cost flies out of the HUD, which drops by it, the score no lower than
    # 0, and the beat goes on.
    def too_soon
      popped = dot(T::BRIGHT)
      peeking = dot(T::NEXT)
      x = popped.x + ((popped.x - peeking.x).positive? ? 0.5 : -0.5) * popped.radius
      how.call(x, popped.y)
      check_equal([0, 7], shown, "a tap on the popped dot costs two seconds, the score staying at 0")
      wait(0.25)
      keep_screenshot(name("3-slip"))
      check(cabinet.game.nil? && story.none?(:Penalized), "the rules hear nothing yet: no clock is running")
      check(tutorial.beat == :warn || tutorial.beat == :slide, "the beat goes on")
    end

    # The row beat, on dots of its own: the row fills as the player
    # pops, the star dot comes, its reward shows, and nothing of it reaches
    # the numbers the game goes on with.
    def the_dots_in_a_row
      wait_for("the streak's row", within: 300) { tutorial.beat == :practice }
      keep_screenshot(name("5-row"))
      before = tutorial.hud.dots_in_a_row
      T::PRACTICE.downto(T::PRACTICE - 1).each do |id|
        target = dot(id)
        how.call(target.x, target.y)
        wait(look.flight + 0.05)
      end
      check_equal(before + 2, tutorial.hud.dots_in_a_row, "the row fills as the player pops")
      keep_screenshot(name("5-fills"))
      last = dot(T::PRACTICE - 2)
      how.call(last.x, last.y)
      wait_for("the star dot", within: 300) { tutorial.beat == :bonus }
      check(tutorial.hud.ready, "the full row turns to the star")
      check(dot(T::BONUS).bonus?, "the star dot arrives")
      wait(0.3)
      keep_screenshot(name("5-star"))
      kept = shown
      star = dot(T::BONUS)
      how.call(star.x, star.y)
      check_equal(:reward, tutorial.beat, "popping the star dot shows its reward")
      wait(0.25)
      keep_screenshot(name("5-reward"))
      check_equal(kept, shown, "the reward stays out of the score and time")
      wait_for("the rehearsal to leave", within: 300) { tutorial.nil? || tutorial.beat == :ending }
      check(tutorial.nil? || tutorial.dots.none? { it.id.negative? }, "its dots are put away")
    end

    def look = DotPopper::Presentation::Look::TUTORIAL.dots_in_a_row

    # The last pop spawns a bright dot under the two popped ones, and the
    # game goes on from there: the same dots, the point and the 8 seconds
    # the two wrong taps left, and only the clock starts.
    def now_it_runs
      wait_for("the light on the clock", within: 300) { tutorial.nil? || tutorial.beat == :ending }
      check_equal([true, true, false], (tutorial || game).dots.map(&:popped?),
                  "as time flows, its pop spawns a bright dot under them")
      scene = tutorial&.dots&.map(&:id)
      keep_screenshot(name("4-handover")) if scene
      wait_for("the game", within: 300) { show.playing? }
      check_equal([T::BRIGHT, T::NEXT, T::LAST], game.dots.map(&:id), "the game goes on with the tutorial's dots")
      check_equal([true, true, false], game.dots.map(&:popped?), "popped and fresh as they were")
      check_equal(1, game.score, "and its point")
      check(game.countdown.remaining <= 8.0 && game.countdown.remaining > 7.8,
            "and its 8 seconds, the clock only now starting (#{game.countdown.remaining})")
      check_equal([1, 8], [show.hud.score, show.hud.seconds], "the HUD shows the same numbers")
      check(show.lead_in, "the clock is lit as it starts to run")
      wait(0.3)
      keep_screenshot(name("4-runs"))
      check_equal(%i[RoundStarted], story.uniq - %i[TitleShown], "the tutorial told the rules nothing until then")
      wait(1.2)
      check(game.countdown.remaining < 7.0, "the clock runs")
    end
  end
end

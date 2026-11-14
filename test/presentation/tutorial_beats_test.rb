# frozen_string_literal: true

require_relative "presentation_helper"

# What the tutorial shows, beat by beat, pinned on three screens: a
# desktop window, an upright phone, where the dots part up and down, and
# a phone on its side. Each frame of the Show is watched, and every
# change of beat and of the HUD's score, whole seconds and row is
# noted with its frame, with where the first two bright dots are as
# each beat begins. A player taps each bright dot once time has
# stopped for it. The tutorial's look and timing are tuned by eye
# (doc/design/tutorial.md), so any change to them shows here first.
class TutorialBeatsTest < Minitest::Test
  include PresentationTest

  STEP = 1 / 60.0

  # [frame, beat, score, whole seconds, row]; where BRIGHT and NEXT are
  # (x, y, to a hundredth) as each beat begins; and from frame to frame,
  # the sounds played and their pitches, the numbers in flight, what the
  # spotlight is on, and every twentieth frame, the guide's place and
  # press.
  TRACES = {
    [1200, 800] => {
      changes: [
        [0, :drift, 0, 10, 0], [60, :aim, 0, 10, 0], [70, :points, 0, 10, 0],
        [102, :points, 1, 10, 0], [134, :points, 1, 11, 0], [167, :points, 1, 11, 1],
        [185, :peek, 1, 11, 1], [223, :warn, 1, 11, 1], [289, :warn, 0, 11, 1],
        [321, :warn, 0, 9, 1], [354, :slide, 0, 9, 0], [424, :aim_next, 0, 9, 0],
        [434, :runs, 0, 9, 0], [468, :runs, 1, 10, 1], [489, :ending, 1, 10, 1],
      ],
      places: {
        drift: [[276.0, 304.0], nil],
        aim: [[216.0, 364.0], nil],
        points: [[211.5, 368.5], nil],
        peek: [[211.5, 368.5], [206.5, 368.5]],
        warn: [[188.5, 391.5], [229.5, 391.5]],
        slide: [[184.0, 396.0], [234.0, 396.0]],
        aim_next: [[151.0, 429.0], [267.0, 429.0]],
        runs: [[148.3, 431.7], [269.7, 431.7]],
        ending: [[148.3, 431.7], [269.7, 431.7]],
      },
      sounds: [
        [70, [[:pop, 1.0]]], [102, [[:tick, 1.5]]],
        [134, [[:tick, 1.0]]], [167, [[:tick, 1.25]]],
        [256, [[:bonk, 1.0]]], [434, [[:pop, 1.0]]],
        [468, [[:tick, 1.5], [:tick, 1.0]]],
      ],
      traveling_numbers: [
        [0, []], [77, [["+1", nil, :score]]],
        [102, []], [109, [["+1", :stopwatch, :time]]],
        [134, []], [142, [["+1", :dot, :dots_in_a_row]]],
        [167, []], [264, [["−1", nil, :score]]],
        [289, []], [296, [["−2", :stopwatch, :time]]],
        [321, []], [329, [["−1", :dot, :dots_in_a_row]]],
        [354, []], [441, [["+1", nil, :score], ["+1", :stopwatch, :time], ["+1", :dot, :dots_in_a_row]]],
        [468, []],
      ],
      spotlight: [
        [60, 0], [77, :score],
        [109, :time], [142, :dots_in_a_row],
        [185, nil], [223, 0],
        [354, 1], [441, nil],
        [489, :time],
      ],
      guide: [
        [60, 253.5, 409.0, 0.0], [80, 214.0, 371.5, 0.0], [240, 191.3, 404.8, 0.0], [260, 184.0, 396.0, 1.0],
        [280, 189.7, 402.8, 0.0], [300, 221.5, 441.0, 0.0], [320, 221.3, 440.8, 0.0], [340, 182.0, 329.0, 0.0],
        [360, 174.0, 166.0, 0.0], [380, 174.0, 166.0, 0.0], [400, 174.0, 166.0, 0.0], [420, 174.0, 166.0, 0.0],
        [440, 279.1, 443.0, 0.0],
      ],
    },
    [400, 850] => {
      changes: [
        [0, :drift, 0, 10, 0], [60, :aim, 0, 10, 0], [70, :points, 0, 10, 0],
        [102, :points, 1, 10, 0], [134, :points, 1, 11, 0], [167, :points, 1, 11, 1],
        [185, :peek, 1, 11, 1], [218, :warn, 1, 11, 1], [284, :warn, 0, 11, 1],
        [316, :warn, 0, 9, 1], [349, :slide, 0, 9, 0], [419, :aim_next, 0, 9, 0],
        [429, :runs, 0, 9, 0], [463, :runs, 1, 10, 1], [484, :ending, 1, 10, 1],
      ],
      places: {
        drift: [[92.0, 323.0], nil],
        aim: [[56.0, 359.0], nil],
        points: [[53.3, 361.7], nil],
        peek: [[53.3, 361.7], [53.3, 364.7]],
        warn: [[42.5, 350.9], [42.5, 375.5]],
        slide: [[39.8, 348.2], [39.8, 378.2]],
        aim_next: [[40.0, 328.4], [40.0, 398.0]],
        runs: [[41.62, 326.78], [41.62, 399.62]],
        ending: [[41.62, 326.78], [41.62, 399.62]],
      },
      sounds: [
        [70, [[:pop, 1.0]]], [102, [[:tick, 1.5]]],
        [134, [[:tick, 1.0]]], [167, [[:tick, 1.25]]],
        [251, [[:bonk, 1.0]]], [429, [[:pop, 1.0]]],
        [463, [[:tick, 1.5], [:tick, 1.0]]],
      ],
      traveling_numbers: [
        [0, []], [77, [["+1", nil, :score]]],
        [102, []], [109, [["+1", :stopwatch, :time]]],
        [134, []], [142, [["+1", :dot, :dots_in_a_row]]],
        [167, []], [259, [["−1", nil, :score]]],
        [284, []], [291, [["−2", :stopwatch, :time]]],
        [316, []], [324, [["−1", :dot, :dots_in_a_row]]],
        [349, []], [436, [["+1", nil, :score], ["+1", :stopwatch, :time], ["+1", :dot, :dots_in_a_row]]],
        [463, []],
      ],
      spotlight: [
        [60, 0], [77, :score],
        [109, :time], [142, :dots_in_a_row],
        [185, nil], [218, 0],
        [349, 1], [436, nil],
        [484, :time],
      ],
      guide: [
        [60, 78.5, 386.0, 0.0], [80, 54.8, 363.5, 0.0], [220, 63.5, 376.3, 0.0], [240, 40.2, 348.7, 0.0],
        [260, 39.8, 348.2, 1.0], [280, 49.8, 360.1, 0.0], [300, 62.3, 375.2, 0.0], [320, 59.0, 371.2, 0.0],
        [340, 42.7, 272.0, 0.18], [360, 45.0, 210.2, 0.0], [380, 45.0, 210.2, 0.0], [400, 45.0, 210.2, 0.0],
        [420, 45.0, 210.8, 0.0], [440, 42.5, 400.6, 0.0],
      ],
    },
    [850, 400] => {
      changes: [
        [0, :drift, 0, 10, 0], [60, :aim, 0, 10, 0], [70, :points, 0, 10, 0],
        [102, :points, 1, 10, 0], [134, :points, 1, 11, 0], [167, :points, 1, 11, 1],
        [185, :peek, 1, 11, 1], [223, :warn, 1, 11, 1], [289, :warn, 0, 11, 1],
        [321, :warn, 0, 9, 1], [354, :slide, 0, 9, 0], [424, :aim_next, 0, 9, 0],
        [434, :runs, 0, 9, 0], [468, :runs, 1, 10, 1], [489, :ending, 1, 10, 1],
      ],
      places: {
        drift: [[195.5, 152.0], nil],
        aim: [[159.5, 188.0], nil],
        points: [[156.8, 190.7], nil],
        peek: [[156.8, 190.7], [153.8, 190.7]],
        warn: [[143.0, 204.5], [167.6, 204.5]],
        slide: [[140.3, 207.2], [170.3, 207.2]],
        aim_next: [[120.5, 227.0], [190.1, 227.0]],
        runs: [[118.88, 228.62], [191.72, 228.62]],
        ending: [[118.88, 228.62], [191.72, 228.62]],
      },
      sounds: [
        [70, [[:pop, 1.0]]], [102, [[:tick, 1.5]]],
        [134, [[:tick, 1.0]]], [167, [[:tick, 1.25]]],
        [256, [[:bonk, 1.0]]], [434, [[:pop, 1.0]]],
        [468, [[:tick, 1.5], [:tick, 1.0]]],
      ],
      traveling_numbers: [
        [0, []], [77, [["+1", nil, :score]]],
        [102, []], [109, [["+1", :stopwatch, :time]]],
        [134, []], [142, [["+1", :dot, :dots_in_a_row]]],
        [167, []], [264, [["−1", nil, :score]]],
        [289, []], [296, [["−2", :stopwatch, :time]]],
        [321, []], [329, [["−1", :dot, :dots_in_a_row]]],
        [354, []], [441, [["+1", nil, :score], ["+1", :stopwatch, :time], ["+1", :dot, :dots_in_a_row]]],
        [468, []],
      ],
      spotlight: [
        [60, 0], [77, :score],
        [109, :time], [142, :dots_in_a_row],
        [185, nil], [223, 0],
        [354, 1], [441, nil],
        [489, :time],
      ],
      guide: [
        [60, 182.0, 215.0, 0.0], [80, 158.3, 192.5, 0.0], [240, 144.7, 212.5, 0.0], [260, 140.3, 207.2, 1.0],
        [280, 143.7, 211.3, 0.0], [300, 162.8, 234.2, 0.0], [320, 162.7, 234.1, 0.0], [340, 139.1, 167.0, 0.0],
        [360, 134.3, 69.2, 0.0], [380, 134.3, 69.2, 0.0], [400, 134.3, 69.2, 0.0], [420, 134.3, 69.2, 0.0],
        [440, 197.3, 235.4, 0.0],
      ],
    },
  }.freeze

  def test_the_beats_and_the_hud_are_as_they_were_on_every_screen
    TRACES.each do |(width, height), expected|
      assert_equal expected, self.class.trace(width, height), "#{width}x#{height}"
    end
  end

  def test_the_game_after_it_has_the_tutorials_dots_score_time_and_row
    TRACES.each_key do |width, height|
      game = self.class.play(width, height).cabinet.game
      name = "#{width}x#{height}"

      assert_equal [0, 1, 2], game.dots.map(&:id), name
      assert_equal [true, true, false], game.dots.map(&:popped?), name
      assert_equal [1, 1], [game.score, game.dots_in_a_row], name
      assert_in_delta 10.0, game.countdown.remaining, STEP, name
    end
  end

  # Plays the tutorial on a +width+ by +height+ screen through to the
  # game, and answers its Show; with a block, it hears the Show each
  # frame.
  def self.play(width, height)
    radius = DotPopper::DotSize.standard(width, height).radius
    cabinet = DotPopper::Cabinet.new(DotPopper::Field.new(width, height, radius), random: Random.new(2))
    screen = Layout.new(width:, height:, safe: Rect.new(x: 0, y: 0, width:, height:), style: Style::LAYOUT)
    show = PresentationTest.show(cabinet:, layout: screen, sounds: FakeSounds.new, radius:, random: Random.new(3),
                    tutorial_flag: TutorialFlag.new(DotPopper::ScoreRecord::Memory.new))
    reach = show.play_reach
    show.tap(reach.center_x, reach.center_y)
    tapped = []
    frame = 0
    while show.tutorial?
      yield show, frame if block_given?
      tutorial = show.tutorial
      target = { aim: 0, aim_next: 1 }[tutorial.beat]
      if target && tutorial.rate.zero? && !tapped.include?(target)
        tapped << target
        dot = tutorial.dots.find { it.id == target }
        show.tap(dot.x, dot.y)
      end
      cabinet.update(STEP)
      show.update(STEP)
      frame += 1
      raise "the tutorial never ended" if frame > 3600
    end
    show
  end

  def self.trace(width, height)
    changes = []
    places = {}
    seen = Hash.new { |hash, key| hash[key] = [] }
    heard = 0
    play(width, height) do |show, frame|
      tutorial = show.tutorial
      hud = tutorial.hud
      now = [tutorial.beat, hud.score, hud.seconds, hud.dots_in_a_row]
      changes << [frame, *now] if changes.empty? || changes.last.drop(1) != now
      places[tutorial.beat] ||= [0, 1].map do |id|
        tutorial.dots.find { it.id == id }&.then { [it.x.round(2), it.y.round(2)] }
      end
      played = show.sounds.played
      seen[:sounds] << [frame, played.drop(heard).map { |name, pitch| [name, pitch.round(3)] }] if played.size > heard
      heard = played.size
      noted(seen[:traveling_numbers], frame, tutorial.traveling_numbers.map { [it.text, it.icon, it.to.name] })
      noted(seen[:spotlight], frame, tutorial.spotlight.to&.name)
      pose = tutorial.guide_pose
      seen[:guide] << [frame, pose.x.round(1), pose.y.round(1), pose.press.round(2)] if pose && (frame % 20).zero?
    end
    { changes:, places:, **seen }
  end

  # Notes +value+ at +frame+ when it differs from the last noted.
  def self.noted(list, frame, value)
    list << [frame, value] unless list.last&.last == value
  end
end

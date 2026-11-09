# frozen_string_literal: true

module DotPopperGui
  # The title in every state that matters, at every size that matters,
  # kept as screenshots to look at side by side: a first launch, a
  # returning player's title with a best, today's goal and a streak, the
  # goal done, and the words for the mouse, a finger and a gamepad; on a
  # desktop's windows, and on phone-shaped ones laid out as a phone lays
  # them out, without "Full screen" or Quit. It checks nothing but that
  # the title shows; DOT_POPPER_GALLERY names the shots (as "before").
  # Not part of rake test:gui: it is for reviewing the title's design.
  class TitleGalleryScenario < Scenario
    scenario :title_gallery

    DESKTOP = [[1200, 800], [1920, 1080], [800, 500], [400, 320]].freeze
    PHONE = [[400, 850], [850, 400]].freeze
    FULL = [1920, 1080].freeze # fullscreen, since a window that big does not fit the session's display
    P = DotPopper::Presentation

    def play
      check(show.title?, "the game opens on the title")
      @desktop = show.window
      each_size { shoot("first") }
      quick_game
      returning(done: false)
      each_size { shoot("returning") }
      [P::InputKind::TOUCH, P::InputKind::GAMEPAD].each do |kind|
        [[1200, 800, false], [400, 850, true]].each do |width, height, phone|
          at(width, height, phone:) do
            kind == P::InputKind::GAMEPAD ? pad(:dpup) : show.input = kind
            shoot("returning-#{kind.name}")
          end
        end
      end
      move(layout.center_x + 40, 2) # the mouse again, which hides the gamepad's cursor
      returning(done: true)
      each_size { shoot("done") }
      at(1200, 800) do
        pad(:b)
        wait(0.3)
        shoot("quit-asked", settle: 0)
      end
    end

    private

    def tag = ENV.fetch("DOT_POPPER_GALLERY", "gallery")

    def each_size(&)
      DESKTOP.each { |width, height| at(width, height, &) }
      PHONE.each { |width, height| at(width, height, phone: true, &) }
    end

    # The window at +width+ by +height+, as a desktop's or as a phone's.
    def at(width, height, phone: false)
      show.instance_variable_set(:@window, phone ? P::NoWindowControl.new : @desktop)
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
      if [width, height] == FULL
        fullscreen(true) unless L::Window.fullscreen.first
      else
        fullscreen(false) if L::Window.fullscreen.first
        resize(width, height) unless L::Graphics.dimensions == [width, height]
      end
      @phone = phone
      yield
    end

    def shoot(state, settle: 1.2)
      wait(settle)
      kind = @phone ? "phone" : "desktop"
      keep_screenshot("#{tag}-#{state}-#{kind}-#{layout.width.round}x#{layout.height.round}")
    end

    # A returning player's records: a best of 24, three days in a row of
    # today's goal, and today's met once +done+.
    def returning(done:)
      today = show.lifetime.today
      stats = show.lifetime.stats
      met = done ? today : today - 1
      streak = stats.streak.with(current: done ? 4 : 3, longest: 4, last_met: met.iso8601)
      show.lifetime.restore(stats.with(streak:).to_text)
      cabinet.best.restore("#{cabinet.size_class.name}=24\n#{DotPopper::SizeClass::FITTED.name}=24\n")
      show.send(:records_changed)
    end
  end
end

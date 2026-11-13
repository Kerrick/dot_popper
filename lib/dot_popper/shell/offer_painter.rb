# frozen_string_literal: true

module DotPopper
  module Shell
    # The offer of Pro, over the screen where it was asked for: the
    # heading and Back, then what was tapped, shown (every theme Pro gives,
    # the achievement and how to earn it, or the feature's sign), its name,
    # the rest of what Pro adds, each after its sign, the price from the
    # store on Buy, and Restore Purchases; or, once it is the player's,
    # thanks. Calm: no motion, no countdown, and Back always there.
    # Presentation::OfferScreen decides where each goes; this only draws,
    # on whole device pixels.
    class OfferPainter < Data.define(:pen, :dots)
      G = ::Lota::Graphics
      SIGNS = { "Unlimited games" => :infinity, "Achievements" => :ribbon, "Friend groups" => :crown }.freeze

      def draw(show, layout)
        plan = show.offer_plan
        words = show.words.offer
        palette = pen.palette
        Header.new(pen:).draw(show, layout, words[:heading])
        note(plan) if plan.key?(:note)
        art(show, plan[:art]) if plan.key?(:art)
        centered(plan, :focus, :bold, :focus, show.offer_screen.focus_word, palette.cream)
        items(plan, show.offer_screen.others)
        status(plan, show.offer_status)
        buttons(show, plan, words)
      end

      private

      def centered(plan, name, face, size, text, color)
        rect = plan[name] or return
        pen.text(text, pen.fonts.public_send(face, plan.size(size)), rect.center_x, rect.center_y, color)
      end

      def note(plan)
        font = pen.fonts.semibold(plan.size(:note))
        plan.note_lines.each_with_index do |line, i|
          pen.text(line, font, plan[:note].center_x, plan[:note].y + (font.height * (i + 0.5)), pen.palette.alarm)
        end
      end

      # What was tapped, shown in the room the plan gives it.
      def art(show, rect)
        case show.offer_focus
        when :themes then themes(show, rect)
        when :achievements then achievement(show, rect)
        else Glyphs.new(pen:).draw(show.offer_focus == :groups ? :crown : :infinity, rect.center_x, rect.center_y, rect.height,
                                   color: pen.palette.bright_body, weight: 2.0)
        end
      end

      # A small card for each theme Pro would give, each its own night and
      # dots, in a row.
      def themes(show, rect)
        list = show.offer_themes
        return if list.empty?

        gap = 10.0
        width = [(rect.width - (gap * (list.size - 1))) / list.size, rect.height * 1.3].min
        left = rect.center_x - (((list.size * width) + ((list.size - 1) * gap)) / 2.0)
        list.each_with_index do |theme, i|
          box = Presentation::Rect.new(x: left + (i * (width + gap)), y: rect.y, width:, height: rect.height)
          pen.color(theme.palette.ink_top)
          G.rectangle(:fill, box.x, box.y, box.width, box.height, 12, 12, 24)
          radius = [box.height * 0.24, box.width * 0.17].min
          pen.using(theme) do
            dots.icon(box.center_x - (radius * 0.6), box.y + (box.height * 0.4), radius, bright: true)
            dots.icon(box.center_x + (radius * 0.6), box.y + (box.height * 0.4), radius, bright: false)
          end
          name = show.words.themes.fetch(theme.key)
          art = theme.art
          name = name.upcase if art&.wordmark && art.title_dots
          size = [(box.height * 0.16).round, 18].min
          size -= 1 while size > 9 && pen.fonts.face(art&.wordmark || pen.style::TYPE.bold, size).width(name) > box.width * 0.9
          pen.text(name, pen.fonts.face(art&.wordmark || pen.style::TYPE.bold, size), box.center_x, box.bottom - (box.height * 0.18),
                   theme.palette.bright_body)
        end
      end

      # The achievement tapped, on a card: its sign in the grid's dashed
      # ring, its name, and how to earn it. No progress: that is what Pro
      # adds (doc/design/store-and-pro.md).
      def achievement(show, rect)
        id = show.offer_achievement or return
        Card.new(pen:).draw(rect)
        radius = rect.height * 0.32
        x = rect.x + 16 + radius
        AchievementsPainter.new(pen:).emblem(id, x, rect.center_y, radius, show.achievement_earned?(id))
        left = x + radius + 16
        room = rect.right - left - 16
        bold = pen.fonts.bold(18)
        small = pen.fonts.semibold(14)
        lines = Presentation::Words.wrap(Presentation::AchievementWords.how(id), room) { small.width(it) }.first(3)
        top = rect.center_y - (((lines.size * small.height) + bold.height) / 2.0)
        name = Presentation::AchievementWords.name(id)
        pen.text(name, bold, left + (bold.width(name) / 2.0), top + (bold.height / 2.0), pen.palette.cream)
        lines.each_with_index do |line, i|
          pen.text(line, small, left + (small.width(line) / 2.0), top + bold.height + (small.height * (i + 0.5)), pen.palette.cream)
        end
      end

      def items(plan, list)
        rect = plan[:items] or return
        font = pen.fonts.semibold(plan.size(:item))
        line = font.height * Presentation::OfferScreen::LINE
        list.each_with_index do |item, i|
          y = pen.pixels.snap(rect.y + (font.height / 2.0) + (i * line))
          sign = font.height * 1.1
          if SIGNS.key?(item)
            Glyphs.new(pen:).draw(SIGNS[item], rect.x + (sign / 2.0), y, sign, color: pen.palette.bright_body)
          else
            dots.icon(rect.x + (sign / 2.0), y, sign * 0.45, bright: true)
          end
          pen.text(item, font, rect.x + (font.height * 1.6) + (font.width(item) / 2.0), y, pen.palette.cream)
        end
      end

      # How the store or the key is getting on, smaller until it fits across.
      def status(plan, text)
        rect = plan[:status] or return
        size = plan.size(:note)
        size -= 1 while size > 10 && pen.fonts.semibold(size).width(text) > rect.width
        pen.text(text, pen.fonts.semibold(size), rect.center_x, rect.center_y, pen.palette.cream)
      end

      # Buy, while Pro is sold, and Restore Purchases or Paste license key.
      def buttons(show, plan, words)
        if plan.key?(:buy)
          PrimaryButton.new(pen:).draw(plan[:buy], show.buy_label, hover: show.hover.level(:buy))
        end
        %i[restore paste].each { PillButton.new(pen:).draw(plan[it], words[it], hover: show.hover.level(it)) if plan.key?(it) }
      end
    end
  end
end

# frozen_string_literal: true

module DotPopper
  module Presentation
    # The license texts the running build carries, as the shell found them
    # (Shell::NoticeFiles): the game's own license (+agpl+) and the font's
    # (+ofl+), Lota's notices (+lota+), and each of Fledge's (+fledge+).
    # What a build lacks is nil, or empty, and the Credits screen skips it.
    class Notices < Data.define(:agpl, :ofl, :lota, :fledge)
      def self.none = new

      def initialize(agpl: nil, ofl: nil, lota: nil, fledge: []) = super
    end

    # How the Credits screen reads: the type's size, a line's height in
    # it, and the widest a column of text grows (all at a layout scale of
    # 1); the lines a mouse wheel's notch moves it; and how many lines a
    # second a gamepad's stick at full tilt does.
    class CreditsLook < Data.define(:text, :line, :column, :wheel, :stick); end

    # One part of the Credits screen: a +heading+, a +subheading+ over one
    # open-source project's license, a +note+ in the game's own words, or a
    # license's +legal+ text, which is reflowed to fit.
    class CreditsBlock < Data.define(:kind, :text); end

    # What the Credits screen says, in order: who made Dot Popper (and,
    # when the words have it, whom to thank); its own copyright and license
    # notice, with the license's text and the sounds' and icon's; and under
    # "Open-source licenses", Fredoka's, then Lota's notices, then Fledge's.
    # Each license is shown if the build has it.
    class CreditsBook < Data.define(:blocks)
      def self.compose(words, notices)
        say = words.notice
        blocks = [CreditsBlock.new(:heading, say.fetch(:made_by)), CreditsBlock.new(:note, say[:thanks]),
                  CreditsBlock.new(:subheading, say.fetch(:copyright)), CreditsBlock.new(:note, say.fetch(:license)),
                  CreditsBlock.new(:legal, notices.agpl), CreditsBlock.new(:note, say.fetch(:assets)),
                  CreditsBlock.new(:heading, say.fetch(:open_source)),
                  CreditsBlock.new(:subheading, say.fetch(:font_name)), CreditsBlock.new(:note, say.fetch(:font)),
                  CreditsBlock.new(:legal, notices.ofl),
                  CreditsBlock.new(:subheading, say.fetch(:lota)), CreditsBlock.new(:legal, notices.lota),
                  CreditsBlock.new(:subheading, say.fetch(:fledge)),
                  *notices.fledge.map { CreditsBlock.new(:legal, it) }]
        new(blocks: bare(blocks.reject { it.text.to_s.strip.empty? }))
      end

      # +blocks+ with no heading left over nothing.
      def self.bare(blocks)
        blocks.each_with_index.reject { |block, i| over_nothing?(block, blocks[i + 1]) }.map(&:first)
      end

      def self.over_nothing?(block, after)
        case block.kind
        when :heading then after.nil? || after.kind == :heading
        when :subheading then !%i[note legal].include?(after&.kind)
        else false
        end
      end
    end

    # The book's text broken into lines for a column +room+ wide, at type
    # +size+, each with where its middle falls down the page (+y+, from the
    # top), and the page's +height+. A heading is bold and a size larger, a subheading bold.
    # +measure+ is the shell's (or RoughMeasure), which says how wide words
    # are. A license's text is reflowed: its hard-wrapped lines are joined
    # back into paragraphs, but a paragraph that is a list or indented
    # keeps its lines, and a ruled line is dropped. A word wider than the
    # column is broken, so nothing runs off it.
    class CreditsLines < Data.define(:rows, :height, :size)
      Row = Data.define(:kind, :text, :y)
      GAP = { heading: 1.8, subheading: 1.2, note: 0.9, legal: 0.9 }.freeze # lines left above a block
      RULE = /\A\s*[-=_*#~]{4,}\s*\z/

      def self.heading_size(size) = size + [(size * 0.25).round, 1].max

      def self.set(book, size:, room:, line:, measure:)
        step = size * line
        rows = []
        y = 0.0
        book.blocks.each_with_index do |block, i|
          y += step * GAP.fetch(block.kind) unless i.zero?
          broken(block, room, measure, size).each_with_index do |lines, p|
            y += step * 0.6 unless p.zero?
            lines.each do |text|
              rows << Row.new(kind: block.kind, text:, y: y + (step / 2.0))
              y += step
            end
          end
        end
        new(rows:, height: y, size:)
      end

      # The block's paragraphs, each as the lines it breaks into.
      def self.broken(block, room, measure, size)
        face = %i[heading subheading].include?(block.kind) ? :bold : :semibold
        type = block.kind == :heading ? heading_size(size) : size
        width = ->(text) { measure.width(face, type, text) }
        paragraphs = block.kind == :legal ? paragraphs_of(block.text) : [[block.text]]
        paragraphs.map { |lines| lines.flat_map { fit(it, room, &width) } }
      end

      # +text+'s lines, each paragraph as the lines to wrap on their own.
      def self.paragraphs_of(text)
        text.gsub("\r\n", "\n").split(/\n\s*\n/).filter_map do |chunk|
          lines = chunk.lines.map(&:rstrip).grep_v(RULE)
          next if lines.empty?

          lines.any? { it.match?(/\A\s|\A[-*•]\s|\A\d+[.)]\s/) } ? lines.map(&:strip) : [lines.join(" ").split.join(" ")]
        end
      end

      # +text+ in lines no wider than +room+, a word too wide broken.
      def self.fit(text, room, &width)
        Words.wrap(text, room, &width).flat_map do |line|
          next line if width.call(line) <= room

          line.each_char.each_with_object([+""]) do |char, parts|
            (width.call(parts.last + char) <= room || parts.last.empty?) ? parts.last << char : parts << +char
          end
        end
      end

      # The rows that show in a window +height+ tall, +offset+ down the page.
      def visible(offset, height, line)
        reach = line / 2.0
        rows.select { it.y + reach > offset && it.y - reach < offset + height }
      end
    end

    # How far down the page the Credits screen is: the page's +content+
    # height, the +window+ it shows through, and the +offset+ of the window
    # from the top. Every way of scrolling keeps the window on the page.
    class CreditsScroll < Data.define(:offset, :content, :window)
      def self.at_top(content:, window:) = new(offset: 0.0, content:, window:)

      def initialize(offset:, content:, window:) = super(offset: offset.to_f.clamp(0.0, [content - window, 0.0].max), content:, window:)

      def farthest = [content - window, 0.0].max
      def by(pixels) = with(offset: offset + pixels)
      def to_start = with(offset: 0.0)
      def to_end = with(offset: farthest)
      def page(direction) = by(direction * window * 0.9)

      # The same place on a page of another height or window.
      def fitted(content:, window:)
        was = farthest
        fraction = was.positive? ? offset / was : 0.0
        far = [content - window, 0.0].max
        self.class.new(offset: fraction * far, content:, window:)
      end

      # What the arrows, Page keys, Home and End do, for a line +line+ tall.
      def key(name, line:)
        case name.to_s.to_sym
        in :up then by(-line)
        in :down then by(line)
        in :pageup then page(-1)
        in :pagedown then page(1)
        in :home then to_start
        in :end then to_end
        else self
        end
      end

      # Where a scroll bar's thumb goes, as fractions of its track from the
      # top: its start and its length, or nil when the page fits.
      def thumb
        return unless farthest.positive?

        length = window / content
        [(offset / farthest) * (1.0 - length), length]
      end
    end

    # The Credits screen laid out in the safe area: the heading at the
    # top as the Records screen has it, Back along the bottom, and between
    # them the window the text scrolls in, as wide as +look+'s column.
    class CreditsLayout < Data.define(:layout, :look)
      def heading_size = layout.scaled(Look::RECORDS.heading)
      def heading_y = layout.top + (heading_size * 0.6)
      def text_size = [layout.scaled(look.text), RecordsLayout::SMALLEST_TEXT].max
      def line = text_size * look.line
      def room = [layout.safe.width - (layout.margin * 2), layout.scaled(look.column)].min

      def window
        top = heading_y + (heading_size * 0.8) + (layout.margin * 0.5)
        Rect.new(x: layout.center_x - (room / 2.0), y: top, width: room, height: [bottom - top, 0.0].max)
      end

      def bottom = layout.back_button.y - layout.margin
    end
  end
end

# frozen_string_literal: true

module DotPopper
  module Presentation
    # A circle of the icon's, in a unit disc (radius 1, center 0, 0).
    class IconDot < Data.define(:x, :y, :r, :tone); end

    # A filled shape of the icon's, its points flat as x1, y1, x2, y2…
    class IconShape < Data.define(:points, :tone); end

    # A member's face in a group: a disc of two colors, patterned like an
    # old GitHub identicon but game, and drawn by the game, so it looks the
    # same everywhere and no emoji is involved. It is worked out from the
    # group's id and the member's number and nothing else, so everyone sees
    # the same icon, and the server stores none.
    #
    # Members of a group differ by structure, not hue (Westland & Maggio:
    # color alone never carries information). A pattern is a choice of
    # FOLDS, OUTER and INNER motif, and a member's number walks through all
    # of those combinations by a step the group's id picks and coprime with
    # their count, so numbers less than COMBINATIONS apart never repeat one,
    # however many members have come and gone. Light or dark ground comes
    # from the same walk, so neighbors differ in grayscale too.
    class MemberIcon < Data.define(:base, :ink, :accent, :shapes)
      FOLDS = [3, 4, 5, 6, 8].freeze
      OUTER = %i[dots petals diamonds spokes].freeze
      INNER = %i[dot ring star].freeze
      COMBINATIONS = FOLDS.size * OUTER.size * INNER.size
      STEPS = (7...COMBINATIONS).select { it.gcd(COMBINATIONS) == 1 }.freeze
      # Grounds, inks and accents, chosen for contrast at phone size; the
      # first half are dark grounds and the second light.
      SCHEMES = [%w[#1b2a4a #ffd166 #ef476f], %w[#3a1d4d #7bdff2 #f7aef8], %w[#0f4c3a #f4f1de #e07a5f], %w[#5a1a2b #ffe0ac #6fd6c1],
                 %w[#ffd166 #1b2a4a #d1495b], %w[#9be7c4 #14342b #e4572e], %w[#ffc2d1 #4a1942 #2a9d8f], %w[#bde0fe #1d3557 #e76f51]]
                .map { |colors| colors.map { Color.hex(it) }.freeze }.freeze
      DARK = SCHEMES.size / 2
      FNV_OFFSET = 2_166_136_261
      FNV_PRIME = 16_777_619
      MASK = 0xFFFFFFFF

      # A stable hash of +text+, the same on every device and every run,
      # which String#hash is not.
      def self.seed(text) = text.to_s.bytes.reduce(FNV_OFFSET) { |hash, byte| ((hash ^ byte) * FNV_PRIME) & MASK }

      # The pattern member +number+ has in a group, as [fold, outer, inner]
      # indexes, and the +ground+ (0 dark, 1 light).
      def self.pattern(group_id, number)
        seed = seed(group_id)
        combination = ((seed % COMBINATIONS) + (STEPS[(seed >> 8) % STEPS.size] * number)) % COMBINATIONS
        [combination % FOLDS.size, (combination / FOLDS.size) % OUTER.size, (combination / (FOLDS.size * OUTER.size)) % INNER.size,
         (number + (seed >> 16)) % 2]
      end

      def self.of(group_id, number)
        fold, outer, inner, ground = pattern(group_id, number)
        scheme_seed = seed("#{group_id}/#{number}")
        scheme = SCHEMES[ground.zero? ? scheme_seed % DARK : DARK + (scheme_seed % DARK)]
        turn = (scheme_seed >> 8) % 2 == 0 ? 0.0 : Math::PI / FOLDS[fold]
        new(base: scheme[0], ink: scheme[1], accent: scheme[2],
            shapes: [*outer_shapes(OUTER[outer], FOLDS[fold], turn), *inner_shapes(INNER[inner], FOLDS[fold], turn)])
      end

      # A group's own face, for telling groups apart: an icon no member has
      # in its first COMBINATIONS numbers.
      def self.crest(group_id) = of(group_id, -1)

      def self.around(count, turn) = Array.new(count) { (Math::PI * 2 * it / count) + turn - (Math::PI / 2) }

      def self.outer_shapes(motif, fold, turn)
        around(fold, turn).flat_map do |angle|
          case motif
          when :dots then [IconDot.new(x: Math.cos(angle) * 0.62, y: Math.sin(angle) * 0.62, r: 0.2, tone: :ink)]
          when :petals then [petal(angle, 0.28, 0.92, 0.2 + (0.5 / fold))]
          when :diamonds then [diamond(angle, 0.32, 0.92, 0.26 * 4 / fold.clamp(3, 6))]
          when :spokes then [spoke(angle, 0.42, 0.92, 0.09 + (0.24 / fold))]
          end
        end
      end

      def self.inner_shapes(motif, fold, turn)
        case motif
        when :dot then [IconDot.new(x: 0.0, y: 0.0, r: 0.24, tone: :accent)]
        when :ring then [IconDot.new(x: 0.0, y: 0.0, r: 0.3, tone: :accent), IconDot.new(x: 0.0, y: 0.0, r: 0.14, tone: :base)]
        when :star then [star(fold, turn)]
        end
      end

      def self.at(angle, along, across)
        [(Math.cos(angle) * along) - (Math.sin(angle) * across), (Math.sin(angle) * along) + (Math.cos(angle) * across)]
      end

      # A leaf, pointed at both ends and full in the middle.
      def self.petal(angle, inner, outer, half)
        steps = 10
        side = ->(sign) { (1..(steps - 1)).map { |i| at(angle, inner + ((outer - inner) * i / steps), sign * half * Math.sin(Math::PI * i / steps)) } }
        IconShape.new(points: [*at(angle, inner, 0.0), *side[1].flatten, *at(angle, outer, 0.0), *side[-1].reverse.flatten], tone: :ink)
      end

      def self.diamond(angle, inner, outer, half)
        middle = (inner + outer) / 2.0
        IconShape.new(points: [*at(angle, inner, 0.0), *at(angle, middle, half), *at(angle, outer, 0.0), *at(angle, middle, -half)], tone: :ink)
      end

      def self.spoke(angle, inner, outer, half)
        IconShape.new(points: [*at(angle, inner, half), *at(angle, outer, half), *at(angle, outer, -half), *at(angle, inner, -half)], tone: :ink)
      end

      # A star of +fold+ points, its middle held open with a dot-sized hub.
      def self.star(fold, turn)
        points = Array.new(fold * 2) do |i|
          radius = i.odd? ? 0.14 : 0.34
          angle = (Math::PI * i / fold) + turn - (Math::PI / 2)
          [Math.cos(angle) * radius, Math.sin(angle) * radius]
        end
        IconShape.new(points: points.flatten, tone: :accent)
      end
      private_class_method :around, :outer_shapes, :inner_shapes, :at, :petal, :diamond, :spoke, :star

      def color(tone) = { base:, ink:, accent: }.fetch(tone)
    end
  end
end

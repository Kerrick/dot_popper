# frozen_string_literal: true

module DotPopper
  module Presentation
    # What stands in a theme's night, as plain shapes in graphics units:
    # silhouettes of trees, hills, a crooked house, a fence, graves, bats,
    # the wood's trunks, fir boughs and a farm. It knows no drawing library;
    # Shell::Scene bakes these once, for the screen's size, into a canvas
    # at the screen's own resolution.
    #
    # Every shape is convex or a fan about its first point, so a plain
    # filled polygon draws it.
    module Scenery
      Fan = Data.define(:points, :color)
      Dot = Data.define(:x, :y, :radius, :color)

      module_function

      # The shapes for theme kind +kind+ on a +width+ by +height+ field,
      # bottom layer first.
      def for(kind, width, height)
        case kind
        when :graveyard then graveyard(width, height)
        when :dusk then dusk(width, height)
        when :wood then wood(width, height)
        when :churchyard then churchyard(width, height)
        when :boughs then boughs(width, height)
        when :farm then farm(width, height)
        else []
        end
      end

      def tree(out, color, x, y, angle, length, width, depth, random)
        steps = random.rand(3..4)
        points = [[x, y]]
        bent = angle
        steps.times do
          bent += normal(random, 0.22)
          points << [points.last[0] + (Math.cos(bent) * length / steps), points.last[1] + (Math.sin(bent) * length / steps)]
        end
        points.each_cons(2).with_index do |(a, b), i|
          w1 = width * (1 - (i.to_f / steps * 0.45))
          w2 = width * (1 - ((i + 1).to_f / steps * 0.45))
          out << segment(a, b, w1, w2, color)
          out << Dot.new(x: a[0], y: a[1], radius: w1 / 2.0, color:)
        end
        tip = points.last
        out << Dot.new(x: tip[0], y: tip[1], radius: width * 0.27, color:)
        return unless depth.positive?

        random.rand(2..3).times do
          tree(out, color, tip[0], tip[1], bent + random.rand(-0.8..0.8), length * random.rand(0.6..0.82), width * 0.55, depth - 1, random)
        end
        return unless random.rand < 0.6

        side = random.rand < 0.5 ? -1 : 1
        tree(out, color, points[1][0], points[1][1], angle + (side * random.rand(0.6..1.1)), length * 0.6, width * 0.45, depth - 1, random)
      end

      def segment(a, b, w1, w2, color)
        nx = -(b[1] - a[1])
        ny = b[0] - a[0]
        q = Math.hypot(nx, ny).nonzero? || 1.0
        nx /= q
        ny /= q
        Fan.new(color:, points: [[a[0] + (nx * w1 / 2), a[1] + (ny * w1 / 2)], [b[0] + (nx * w2 / 2), b[1] + (ny * w2 / 2)],
                                 [b[0] - (nx * w2 / 2), b[1] - (ny * w2 / 2)], [a[0] - (nx * w1 / 2), a[1] - (ny * w1 / 2)]])
      end

      def normal(random, sigma) = (Array.new(6) { random.rand }.sum - 3.0) * sigma / 0.707

      def hill_strip(out, color, width, height, steps = 48, &ridge)
        (0...steps).each do |i|
          x1 = width * i / steps.to_f
          x2 = width * (i + 1) / steps.to_f
          out << Fan.new(color:, points: [[x1, ridge.call(i / steps.to_f)], [x2, ridge.call((i + 1) / steps.to_f)], [x2, height], [x1, height]])
        end
      end

      WING = [[-1, 0], [-0.72, -0.3], [-0.45, -0.14], [-0.2, -0.05], [-0.12, -0.34], [-0.05, -0.14], [0, -0.1], [0.05, -0.14],
              [0.12, -0.34], [0.2, -0.05], [0.45, -0.14], [0.72, -0.3], [1, 0], [0.6, 0.05], [0.42, 0.3], [0.22, 0.08],
              [0.1, 0.28], [0, 0.14], [-0.1, 0.28], [-0.22, 0.08], [-0.42, 0.3], [-0.6, 0.05]].freeze

      def bat(out, color, x, y, size, tilt)
        c = Math.cos(tilt)
        s = Math.sin(tilt)
        placed = WING.map { |a, b| [x + (size * ((c * a) - (s * b))), y + (size * ((s * a) + (c * b)))] }
        out << Fan.new(color:, points: [[x, y + (size * 0.05)], *placed, placed.first])
      end

      def grave(out, color, x, ground, w, h, cross)
        if cross
          out << Fan.new(color:, points: [[x - (w * 0.28), ground + 4], [x + (w * 0.28), ground + 4], [x + (w * 0.28), ground - (h * 1.5)], [x - (w * 0.28), ground - (h * 1.5)]])
          out << Fan.new(color:, points: [[x - (w * 0.95), ground - (h * 1.1)], [x + (w * 0.95), ground - (h * 1.1)], [x + (w * 0.95), ground - (h * 0.85)], [x - (w * 0.95), ground - (h * 0.85)]])
        else
          out << Fan.new(color:, points: [[x - w, ground + 4], [x + w, ground + 4], [x + w, ground - (h * 0.9)], [x - w, ground - (h * 0.9)]])
          out << Dot.new(x:, y: ground - (h * 0.9), radius: w, color:)
        end
      end

      def churchyard(width, height)
        out = []
        ink = Color.hex("#06050c")
        land = width > height
        ridge = land ? ->(f) { height * (0.86 + (0.04 * Math.sin((f * 3.1) + 1)) + (0.02 * Math.sin(f * 9))) } : ->(f) { height * (0.885 + (0.022 * Math.sin((f * 3.1) + 1)) + (0.012 * Math.sin(f * 9))) }
        hill_strip(out, ink, width, height, &ridge)
        (land ? 18 : 9).times do |i|
          f = -0.05 + (i * 1.1 / (land ? 17 : 8))
          r = Random.new(100 + i)
          tree(out, ink, width * f, ridge.call(f) + 6, -Math::PI / 2 + normal(r, 0.12), r.rand(0.9..2.2) * (land ? 30 : 33), 30 * 0.18, 4, r) if r.rand < 0.65
        end
        ox = land ? 0.86 : 0.84
        tree(out, ink, width * ox, ridge.call(ox) + 10, -Math::PI / 2 - 0.2, land ? 210 : 165, land ? 30 : 24, 5, Random.new(7))
        tree(out, ink, width * 0.06, ridge.call(0.06) + 10, -Math::PI / 2 + 0.28, 170, 26, 5, Random.new(9)) if land
        (land ? 7 : 5).times do |i|
          f = 0.12 + (i * (land ? 0.05 : 0.075))
          grave(out, ink, width * f, ridge.call(f), 4.2 + ((i % 3) * 1.2), 9 + ((i * 7 % 4) * 1.5), i % 3 == 1)
        end
        bats = land ? [[0.22, 0.62, 0.85, 0.2], [0.36, 0.7, 0.6, -0.25], [0.66, 0.64, 0.7, 0.1]] : [[0.2, 0.66, 1.0, 0.25], [0.74, 0.6, 0.75, -0.2], [0.42, 0.74, 0.6, 0.15]]
        bats.each { |x, y, s, t| bat(out, Color.hex("#09091a"), width * x, height * y, 17 * s, t) }
        out
      end

      def graveyard(width, height)
        out = []
        ink = Color.hex("#04081a")
        land = width > height
        ridge = land ? ->(f) { height * (0.86 + (0.025 * Math.sin((f * 4) + 2))) } : ->(f) { height * (0.88 + (0.018 * Math.sin((f * 4) + 2))) }
        hill_strip(out, ink, width, height, &ridge)
        count = land ? 13 : 7
        count.times do |i|
          r = Random.new(50 + i)
          f = (i + 0.5 + r.rand(-0.25..0.25)) / count
          grave(out, ink, width * f, ridge.call(f), r.rand(6.0..9.0), r.rand(15.0..25.0), r.rand < 0.3)
        end
        ox = land ? 0.12 : 0.1
        tree(out, ink, width * ox, ridge.call(ox) + 8, -Math::PI / 2 + 0.2, land ? 200 : 150, land ? 24 : 18, 5, Random.new(6))
        ox = land ? 0.88 : 0.92
        tree(out, ink, width * ox, ridge.call(ox) + 8, -Math::PI / 2 - 0.2, land ? 150 : 120, land ? 20 : 15, 5, Random.new(16))
        out
      end

      def dusk(width, height)
        out = []
        ink = Color.hex("#06040f")
        land = width > height
        ridge = land ? ->(f) { height * (0.87 + (0.03 * Math.sin((f * 3) + 0.4))) } : ->(f) { height * (0.9 + (0.02 * Math.sin((f * 3) + 0.4))) }
        hill_strip(out, ink, width, height, &ridge)
        hx = width * (land ? 0.2 : 0.22)
        hy = ridge.call(0.2)
        s = land ? 2.6 : 2.2
        shell = [[-17, 0], [-16, -22], [-20, -22], [0, -44], [20, -22], [15, -22], [17, 0]]
        out << Fan.new(color: ink, points: [[hx, hy + 6 - (15 * s)], *shell.map { |a, b| [hx + (a * s), hy + 6 + (b * s)] }, [hx + (shell.first[0] * s), hy + 6 + (shell.first[1] * s)]])
        chimney = [[-12, -30], [-12, -44], [-7, -48], [-3, -42], [-3, -30]]
        out << Fan.new(color: ink, points: chimney.map { |a, b| [hx + (a * s), hy + 6 + (b * s)] })
        [[-8, -14], [7, -14]].each do |wx, wy|
          out << Fan.new(color: Color.hex("#8a5a24", 0.65), points: [[hx + ((wx - 2.3) * s), hy + 6 + ((wy - 3) * s)], [hx + ((wx + 2.3) * s), hy + 6 + ((wy - 3) * s)],
                                                                      [hx + ((wx + 2.3) * s), hy + 6 + ((wy + 3) * s)], [hx + ((wx - 2.3) * s), hy + 6 + ((wy + 3) * s)]])
        end
        (land ? 12 : 7).times do |i|
          r = Random.new(300 + i)
          f = 0.3 + (i * 0.75 / ((land ? 12 : 7) - 1))
          tree(out, ink, width * f, ridge.call([f, 1].min) + 4, -Math::PI / 2 + normal(r, 0.15), r.rand(26.0..62.0), 5, 4, r) if r.rand < 0.7
        end
        ox = land ? 0.92 : 0.9
        tree(out, ink, width * ox, ridge.call(ox) + 8, -Math::PI / 2 - 0.22, land ? 190 : 150, land ? 24 : 20, 5, Random.new(13))
        f = 0.32
        while f < 0.72
          gx = width * f
          gy = ridge.call(f)
          out << Fan.new(color: ink, points: [[gx - 2.4, gy + 6], [gx - 2.4, gy - 11], [gx, gy - 14.5], [gx + 2.4, gy - 11], [gx + 2.4, gy + 6]])
          f += land ? 0.018 : 0.031
        end
        bats = land ? [[0.3, 0.55, 0.9, 0.2], [0.56, 0.46, 0.6, -0.2], [0.7, 0.62, 0.75, 0.1]] : [[0.3, 0.58, 1, 0.2], [0.68, 0.5, 0.7, -0.25], [0.5, 0.66, 0.6, 0.1]]
        bats.each { |x, y, sz, t| bat(out, Color.hex("#0a0618"), width * x, height * y, 15 * sz, t) }
        out
      end

      def wood(width, height)
        out = []
        trunks(out, Color.hex("#101d16"), width, height, Random.new(12), [5, (width / 44).to_i].max, 18, 34)
        trunks(out, Color.hex("#070c09"), width, height, Random.new(44), [3, (width / 74).to_i].max, 30, 54)
        out
      end

      def trunks(out, color, width, height, random, count, narrow, wide)
        count.times do |i|
          x = (i + random.rand(0.1..0.9)) / count * width
          w = random.rand(narrow.to_f..wide.to_f)
          lean = normal(random, 8)
          out << Fan.new(color:, points: [[x - (w * 0.55), height + 20], [x + (w * 0.55), height + 20], [x + lean + (w * 0.3), -20], [x + lean - (w * 0.3), -20]])
          5.times do
            y = random.rand(0.05..0.85) * height
            at = x + (lean * (1 - (y / height)))
            side = random.rand < 0.5 ? -1 : 1
            reach = random.rand(0.8..3.2) * w
            out << Fan.new(color:, points: [[at, y - (w * 0.1)], [at, y + (w * 0.22)], [at + (side * reach), y - (reach * 0.55) + (w * 0.08)], [at + (side * reach), y - (reach * 0.55) - (w * 0.03)]])
          end
        end
      end

      # Inside a Christmas tree: fir boughs, far ones paler, reaching in
      # from both sides at every height, with near ones heavy at the top
      # corners.
      def boughs(width, height)
        out = []
        land = width > height
        layers = [[Color.hex("#0b1d18"), land ? 4 : 5, 0.34..0.55, 0.75],
                  [Color.hex("#061210"), land ? 3 : 4, 0.4..0.62, 0.9],
                  [Color.hex("#030a08"), 2, 0.5..0.75, 1.15]]
        presents(out, Color.hex("#050a08"), width, height)
        layers.each_with_index do |(ink, count, reach, scale), layer|
          [[0, 1], [width, -1]].each_with_index do |(x0, side), k|
            r = Random.new(70 + (layer * 10) + k)
            count.times do |b|
              span = layer == 2 ? 0.22 : 0.98
              y0 = (((b + 0.5 + (side.positive? ? 0 : 0.5)) / count * span) - (layer == 2 ? 0.04 : 0.02)) * height + r.rand(-12.0..12.0)
              length = [width, height].min * r.rand(reach) * (land ? 1.25 : 1.0)
              angle = side.positive? ? r.rand(0.05..0.4) : Math::PI - r.rand(0.05..0.4)
              bough(out, ink, x0 - (side * 10), y0, angle, length, r, scale)
            end
          end
        end
        out
      end

      # The floor under the tree, and presents on it, each with a bow.
      def presents(out, color, width, height)
        land = width > height
        floor = height * (land ? 0.9 : 0.93)
        out << Fan.new(color:, points: [[0, floor], [width, floor], [width, height], [0, height]])
        r = Random.new(5)
        x = width * (land ? 0.04 : -0.02)
        while x < width
          w = r.rand(0.7..1.3) * (land ? 96 : 66)
          h = w * r.rand(0.55..1.15)
          gap = r.rand(0.0..1.0) < 0.35 && x > width * 0.2 ? w * 1.4 : 0
          x += gap
          unless gap.positive? && x > width * 0.4 && x < width * 0.6
            out << Fan.new(color:, points: [[x, floor + 2], [x + w, floor + 2], [x + w, floor - h], [x, floor - h]])
            bow(out, color, x + (w / 2), floor - h, w * 0.22)
          end
          x += w + r.rand(2.0..10.0)
        end
      end

      # A bow seen from the front: two loops and two tails.
      def bow(out, color, x, y, size)
        out << Fan.new(color:, points: [[x, y + 1], [x - size, y - (size * 0.75)], [x - (size * 1.15), y - (size * 0.35)], [x - (size * 0.9), y + (size * 0.05)]])
        out << Fan.new(color:, points: [[x, y + 1], [x + (size * 0.9), y + (size * 0.05)], [x + (size * 1.15), y - (size * 0.35)], [x + size, y - (size * 0.75)]])
        out << Dot.new(x:, y: y - (size * 0.1), radius: size * 0.22, color:)
      end

      # A fir bough: a drooping stem with twigs either side, all of them
      # thick with short needles.
      def bough(out, color, x, y, angle, length, random, scale = 1.0)
        steps = 10
        droop = Math.cos(angle).positive? ? 0.06 : -0.06
        points = [[x, y]]
        bent = angle
        steps.times do
          bent += droop
          points << [points.last[0] + (Math.cos(bent) * length / steps), points.last[1] + (Math.sin(bent) * length / steps)]
        end
        points.each_cons(2).with_index do |(a, b), i|
          f = i.to_f / steps
          out << segment(a, b, ((6 * (1 - f)) + 2) * scale, ((6 * (1 - f - (1.0 / steps))) + 2) * scale, color)
          needles(out, color, a, b, 13 * scale * (1 - (f * 0.4)), random)
          next if i.zero?

          dir = Math.atan2(b[1] - a[1], b[0] - a[0])
          [-1, 1].each do |side|
            twig = dir + (side * 0.75) + random.rand(-0.15..0.15)
            reach = length * 0.22 * (1 - (f * 0.6)) * random.rand(0.7..1.0)
            tip = [a[0] + (Math.cos(twig) * reach), a[1] + (Math.sin(twig) * reach) + (reach * 0.15)]
            out << segment(a, tip, 2.4 * scale, 1.2 * scale, color)
            needles(out, color, a, tip, 10 * scale * (1 - (f * 0.4)), random)
          end
        end
      end

      # Short needles either side of the twig from +a+ to +b+, swept forward.
      def needles(out, color, a, b, size, random)
        dir = Math.atan2(b[1] - a[1], b[0] - a[0])
        8.times do |n|
          t = (n + 0.5) / 8.0
          at = [a[0] + ((b[0] - a[0]) * t), a[1] + ((b[1] - a[1]) * t)]
          [-1, 1].each do |side|
            angle = dir + (side * 0.9) + random.rand(-0.12..0.12)
            tip = [at[0] + (Math.cos(angle) * size), at[1] + (Math.sin(angle) * size) + (size * 0.2)]
            out << segment(at, tip, 2.0, 0.8, color)
          end
        end
      end

      # A farm at dusk: a field, a barn and silo, shocks of corn, a fence,
      # and geese going over.
      def farm(width, height)
        out = []
        ink = Color.hex("#07050c")
        land = width > height
        far = ->(f) { height * ((land ? 0.82 : 0.85) + (0.02 * Math.sin((f * 4) + 2.1))) }
        hill_strip(out, Color.hex("#140c18"), width, height, &far)
        ridge = ->(f) { height * ((land ? 0.88 : 0.9) + (0.02 * Math.sin((f * 2.6) + 0.6))) }
        bx = width * (land ? 0.16 : 0.2)
        by = far.call(land ? 0.16 : 0.2) + 6
        s = land ? 1.6 : 1.1
        barn = [[-30, 0], [-30, -30], [-22, -46], [0, -58], [22, -46], [30, -30], [30, 0]]
        out << Fan.new(color: Color.hex("#0d0912"), points: [[bx, by - (25 * s)], *barn.map { |a, b| [bx + (a * s), by + (b * s)] }, [bx + (barn.first[0] * s), by + (barn.first[1] * s)]])
        out << Fan.new(color: Color.hex("#0d0912"), points: [[bx + (34 * s), by], [bx + (50 * s), by], [bx + (50 * s), by - (62 * s)], [bx + (34 * s), by - (62 * s)]])
        out << Dot.new(x: bx + (42 * s), y: by - (62 * s), radius: 8 * s, color: Color.hex("#0d0912"))
        out << Fan.new(color: Color.hex("#8a5a24", 0.55), points: [[bx - (5 * s), by - (40 * s)], [bx + (5 * s), by - (40 * s)], [bx + (5 * s), by - (30 * s)], [bx - (5 * s), by - (30 * s)]])
        hill_strip(out, ink, width, height, &ridge)
        (land ? 7 : 4).times do |i|
          r = Random.new(600 + i)
          f = 0.45 + (i * 0.5 / (land ? 7 : 4)) + r.rand(-0.02..0.02)
          x = width * f
          g = ridge.call(f) + 4
          h = r.rand(38.0..54.0)
          out << Fan.new(color: ink, points: [[x, g - h], [x + (h * 0.3), g], [x - (h * 0.3), g]])
          out << Fan.new(color: ink, points: [[x, g - (h * 0.75)], [x - (h * 0.12), g - (h * 1.05)], [x + (h * 0.02), g - (h * 0.7)]])
          out << Fan.new(color: ink, points: [[x, g - (h * 0.75)], [x + (h * 0.14), g - (h * 1.02)], [x + (h * 0.02), g - (h * 0.7)]])
        end
        f = 0.02
        while f < (land ? 0.42 : 0.4)
          gx = width * f
          gy = ridge.call(f)
          out << Fan.new(color: ink, points: [[gx - 2, gy + 6], [gx - 2, gy - 16], [gx + 2, gy - 16], [gx + 2, gy + 6]])
          f += land ? 0.03 : 0.07
        end
        out << segment([0, ridge.call(0) - 10], [width * 0.42, ridge.call(0.42) - 10], 2.5, 2.5, ink)
        geese = land ? [[0.62, 0.5], [0.6, 0.47], [0.64, 0.47], [0.58, 0.44], [0.66, 0.44]] : [[0.62, 0.56], [0.58, 0.535], [0.66, 0.535], [0.54, 0.51]]
        geese.each do |gx, gy|
          at = [width * gx, height * gy]
          out << segment([at[0] - 9, at[1] - 5], at, 2.2, 2.6, ink)
          out << segment(at, [at[0] + 9, at[1] - 5], 2.6, 2.2, ink)
        end
        out
      end
    end
  end
end

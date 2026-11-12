# frozen_string_literal: true

module DotPopper
  module Presentation
    # What stands in a theme's night, as plain shapes in graphics units:
    # silhouettes of trees, hills, a crooked house, a fence, graves, bats,
    # the wood's trunks, fir boughs and presents, snowy rooftops and a
    # sleigh, a snowy yard, a mantel by the fire, and a farm. It knows no
    # drawing library; Shell::Scene bakes these once, for the screen's
    # size, into a canvas at the screen's own resolution.
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
        when :rooftops then rooftops(width, height)
        when :snowfield then snowfield(width, height)
        when :mantel then mantel(width, height)
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

      # Inside a Christmas tree: fir boughs reaching in from both sides at
      # every height, in two depths, strung with dim lights and hung with
      # far ornaments, and presents on the floor below.
      def boughs(width, height)
        out = []
        land = width > height
        presents(out, Color.hex("#040907"), width, height)
        layers = [[Color.hex("#0a1d17"), land ? 4 : 5, 0.38..0.6, 0.85], [Color.hex("#020806"), 2, 0.5..0.75, 1.15]]
        layers.each_with_index do |(ink, count, reach, scale), layer|
          [[0, 1], [width, -1]].each_with_index do |(x0, side), k|
            r = Random.new(70 + (layer * 10) + k)
            count.times do |b|
              span = layer == 1 ? 0.22 : 0.92
              y0 = (((b + 0.5 + (side.positive? ? 0 : 0.5)) / count * span) - (layer == 1 ? 0.04 : 0.02)) * height + r.rand(-12.0..12.0)
              length = [width, height].min * r.rand(reach) * (land ? 1.25 : 1.0)
              angle = side.positive? ? r.rand(0.05..0.4) : Math::PI - r.rand(0.05..0.4)
              stem = bough(out, ink, x0 - (side * 10), y0, angle, length, r, scale)
              trim(out, stem, r) if layer.zero?
            end
          end
        end
        out
      end

      LIGHTS = [Color.hex("#ffd27a", 0.4), Color.hex("#ff8a7a", 0.35), Color.hex("#9ad6ff", 0.35), Color.hex("#b4f0a0", 0.3)].freeze

      # A far bough's trimmings, kept dim behind the play: a string of
      # small lights along it, and an ornament hung near its tip.
      def trim(out, stem, random)
        stem.each_with_index do |(x, y), i|
          next if i.zero? || i.odd?

          out << Dot.new(x:, y: y + random.rand(2.0..7.0), radius: 2.2, color: LIGHTS[(i / 2) % LIGHTS.size])
        end
        tip = stem[-3]
        drop = random.rand(10.0..22.0)
        out << segment(tip, [tip[0], tip[1] + drop], 1.0, 1.0, Color.hex("#0a1d17"))
        out << Dot.new(x: tip[0], y: tip[1] + drop + 8, radius: 8, color: Color.hex(%w[#2c1c1e #2a2a1c #1c2430].sample(random:)))
        out << Fan.new(color: Color.hex("#0a1d17"), points: [[tip[0] - 2.5, tip[1] + drop - 1], [tip[0] + 2.5, tip[1] + drop - 1], [tip[0] + 2.5, tip[1] + drop + 2], [tip[0] - 2.5, tip[1] + drop + 2]])
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
        points
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

      # Snowy rooftops on Christmas Eve: a far row of houses, near roofs
      # with chimneys, dim lit windows, and a sleigh with its reindeer
      # going over.
      def rooftops(width, height)
        out = []
        land = width > height
        far = Color.hex("#101a3a")
        near = Color.hex("#03050e")
        snow_far = Color.hex("#34457a")
        snow_near = Color.hex("#28345e")
        lamp = Color.hex("#8a6a34", 0.55)
        base = height * (land ? 0.8 : 0.84)
        x = -10.0
        r = Random.new(23)
        while x < width
          w = r.rand(0.8..1.3) * (land ? 70 : 46)
          h = r.rand(0.5..0.9) * w
          house(out, far, snow_far, lamp, x, base + r.rand(0.0..8.0), w, h, r.rand < 0.5, r)
          x += w + r.rand(-6.0..4.0)
        end
        ground = height * (land ? 0.9 : 0.92)
        x = -20.0
        r = Random.new(41)
        while x < width
          w = r.rand(0.9..1.4) * (land ? 130 : 90)
          h = r.rand(0.35..0.6) * w
          house(out, near, snow_near, lamp, x, ground, w, h, true, r)
          x += w + r.rand(4.0..20.0)
        end
        out << Fan.new(color: near, points: [[0, ground], [width, ground], [width, height], [0, height]])
        snowy_fir(out, near, snow_near, width * (land ? 0.07 : 0.1), ground + 6, height * (land ? 0.55 : 0.42), land ? 120 : 82)
        snowy_fir(out, near, snow_near, width * (land ? 0.95 : 0.93), ground + 6, height * (land ? 0.36 : 0.27), land ? 80 : 56)
        sleigh(out, Color.hex("#060a1c"), width * (land ? 0.72 : 0.8), height * (land ? 0.3 : 0.36), land ? 1.7 : 1.35)
        out
      end

      # A house seen from the street: walls, a gable roof with snow along
      # its edges, a chimney, and perhaps a lit window.
      def house(out, color, snow, lamp, x, ground, w, h, chimney, random)
        roof = h * 0.55
        out << Fan.new(color:, points: [[x, ground + 4], [x + w, ground + 4], [x + w, ground - h], [x, ground - h]])
        if chimney
          cx = x + (w * random.rand(0.6..0.78))
          out << Fan.new(color:, points: [[cx, ground - h - (roof * 0.2)], [cx + (w * 0.11), ground - h - (roof * 0.2)],
                                          [cx + (w * 0.11), ground - h - (roof * 0.95)], [cx, ground - h - (roof * 0.95)]])
          out << Fan.new(color: snow, points: [[cx - 1.5, ground - h - (roof * 0.95)], [cx + (w * 0.11) + 1.5, ground - h - (roof * 0.95)],
                                               [cx + (w * 0.11) + 1, ground - h - (roof * 0.95) - 3.5], [cx - 1, ground - h - (roof * 0.95) - 3.5]])
          smoke(out, cx + (w * 0.055), ground - h - (roof * 0.95) - 6, w * 0.22) if random.rand < 0.5
        end
        out << Fan.new(color:, points: [[x + (w / 2), ground - h - roof], [x + w + (w * 0.06), ground - h + 2], [x - (w * 0.06), ground - h + 2]])
        t = [w * 0.035, 2.5].max
        out << segment([x - (w * 0.06), ground - h + 1], [x + (w / 2), ground - h - roof], t, t, snow)
        out << segment([x + (w / 2), ground - h - roof], [x + w + (w * 0.06), ground - h + 1], t, t, snow)
        return unless random.rand < 0.45

        wx = x + (w * random.rand(0.2..0.6))
        wy = ground - (h * random.rand(0.45..0.7))
        s = w * 0.12
        out << Fan.new(color: lamp, points: [[wx, wy], [wx + s, wy], [wx + s, wy + (s * 1.2)], [wx, wy + (s * 1.2)]])
      end

      # A tall fir in snow: tiers, each with snow along its lower edge.
      def snowy_fir(out, color, snow, x, ground, h, w)
        out << Fan.new(color:, points: [[x - (w * 0.06), ground], [x + (w * 0.06), ground], [x + (w * 0.06), ground - (h * 0.12)], [x - (w * 0.06), ground - (h * 0.12)]])
        tiers = 6
        tiers.times do |i|
          f = i.to_f / tiers
          bottom = ground - (h * 0.08) - (h * 0.82 * f)
          half = w * (1 - (f * 0.85)) / 2
          top = bottom - (h * 0.3)
          edge = [[x - half, bottom], [x - (half * 0.5), bottom - (h * 0.025)], [x, bottom + (h * 0.01)], [x + (half * 0.5), bottom - (h * 0.025)], [x + half, bottom]]
          out << Fan.new(color:, points: [[x, top], *edge, [x, top]])
          edge.each_cons(2) { |a, b| out << segment(a, b, [h * 0.012, 2.0].max, [h * 0.012, 2.0].max, snow) }
        end
      end

      # Smoke rising from a chimney at +x+, +y+, faint, drifting left.
      def smoke(out, x, y, size)
        8.times do |i|
          f = i / 7.0
          out << Dot.new(x: x - (f * size * 2.2) + (Math.sin(f * 5) * size * 0.3), y: y - (f * size * 4), radius: size * (0.25 + (f * 0.55)),
                         color: Color.hex("#8a96c0", 0.07 * (1 - (f * 0.6))))
        end
      end

      REINDEER = [[-1.0, 0.0], [-0.7, -0.25], [-0.2, -0.3], [0.35, -0.28], [0.62, -0.5], [0.8, -0.62], [0.95, -0.55], [0.82, -0.4],
                  [0.7, -0.15], [0.55, 0.05], [0.7, 0.42], [0.58, 0.45], [0.38, 0.1], [-0.3, 0.12], [-0.62, 0.45], [-0.75, 0.42],
                  [-0.68, 0.1]].freeze

      # Santa's sleigh and four reindeer, flying up to the left.
      def sleigh(out, color, x, y, scale)
        tilt = -0.18
        place = lambda do |px, py|
          [x + (scale * ((Math.cos(tilt) * px) - (Math.sin(tilt) * py))), y + (scale * ((Math.sin(tilt) * px) + (Math.cos(tilt) * py)))]
        end
        body = [[0, -2], [14, -2], [18, -9], [22, -10], [21, -4], [17, 4], [2, 5], [-3, 8], [24, 8], [27, 5], [28, 7], [24, 11], [-4, 11], [-6, 6]]
        out << Fan.new(color:, points: [place.call(10, 3), *body.map { |a, b| place.call(a, b) }, place.call(*body.first)])
        out << Fan.new(color:, points: [place.call(5, -2), place.call(4, -11), place.call(9, -14), place.call(13, -9), place.call(12, -2)])
        lead = [0, 0]
        4.times do |i|
          hx = -24 - (i * 19)
          hy = -6 - (i * 1.5)
          deer = REINDEER.map { |a, b| place.call(hx + (a * 8), hy + (b * 8)) }
          out << Fan.new(color:, points: [place.call(hx, hy), *deer, deer.first])
          out << segment(place.call(hx + 6, hy - 4), place.call(hx + 4, hy - 9), 1.2, 0.8, color)
          out << segment(place.call(hx + 7, hy - 4), place.call(hx + 9, hy - 9), 1.2, 0.8, color)
          lead = [hx, hy]
        end
        out << segment(place.call(-2, 0), place.call(lead[0] + 6, lead[1] - 1), 0.9, 0.9, color)
      end

      # A snowy yard on a winter night: drifts in two depths, a cottage
      # with lit windows behind a picket fence, snowy firs, and a lamp
      # post. The snow is lighter than the sky, as snow is at night.
      def snowfield(width, height)
        out = []
        land = width > height
        far = Color.hex("#1c2a50")
        near = Color.hex("#2a3a66")
        ink = Color.hex("#070c1e")
        snow = Color.hex("#3a4c80")
        lamp = Color.hex("#8a6a34", 0.6)
        back = ->(f) { height * ((land ? 0.8 : 0.84) + (0.025 * Math.sin((f * 3.2) + 0.8))) }
        hill_strip(out, far, width, height, &back)
        r = Random.new(91)
        (land ? 9 : 6).times do |i|
          f = (i + r.rand(0.1..0.9)) / (land ? 9 : 6)
          snowy_fir(out, ink, Color.hex("#24345e"), width * f, back.call(f) + 4, height * r.rand(0.1..0.17), (land ? 46 : 34) * r.rand(0.8..1.2))
        end
        cx = width * (land ? 0.7 : 0.66)
        house(out, ink, snow, lamp, cx, back.call(0.68) + 10, land ? 120 : 84, land ? 70 : 50, true, Random.new(4))
        front = ->(f) { height * ((land ? 0.9 : 0.92) + (0.02 * Math.sin((f * 2.4) + 2.0))) }
        f = 0.0
        while f < 1.0
          gx = width * f
          gy = front.call(f) - 2
          out << Fan.new(color: ink, points: [[gx - 3, gy + 8], [gx - 3, gy - 16], [gx, gy - 20], [gx + 3, gy - 16], [gx + 3, gy + 8]])
          out << segment([gx - 3, gy - 17], [gx + 3, gy - 17], 2.5, 2.5, snow)
          f += land ? 0.022 : 0.045
        end
        out << segment([0, front.call(0) - 10], [width, front.call(1) - 10], 2.5, 2.5, ink)
        hill_strip(out, near, width, height, &front)
        snowy_fir(out, ink, snow, width * (land ? 0.06 : 0.08), front.call(0.06) + 8, height * (land ? 0.5 : 0.38), land ? 110 : 76)
        lx = width * (land ? 0.36 : 0.84)
        ly = front.call(lx / width) + 4
        out << segment([lx, ly], [lx, ly - (height * 0.2)], 4, 3, ink)
        out << Fan.new(color: ink, points: [[lx - 8, ly - (height * 0.2)], [lx + 8, ly - (height * 0.2)], [lx + 5, ly - (height * 0.2) - 16], [lx - 5, ly - (height * 0.2) - 16]])
        out << Fan.new(color: lamp, points: [[lx - 5, ly - (height * 0.2) - 2], [lx + 5, ly - (height * 0.2) - 2], [lx + 3.5, ly - (height * 0.2) - 13], [lx - 3.5, ly - (height * 0.2) - 13]])
        out
      end

      # A parlor on Christmas Eve, by firelight: striped paper on the far
      # wall and a wreath, the mantel with a garland, a jar of candy canes
      # and candles on it, stockings hung from it with candy canes in them,
      # and the fire's opening below, its logs and low flames.
      def mantel(width, height)
        out = []
        land = width > height
        wall = Color.hex("#1a4434", 0.22)
        far = Color.hex("#0e241c")
        ink = Color.hex("#030806")
        stripe = land ? 46.0 : 34.0
        x = stripe * 0.3
        while x < width
          out << Fan.new(color: wall, points: [[x, -5], [x + (stripe * 0.32), -5], [x + (stripe * 0.32), height], [x, height]])
          x += stripe
        end
        shelf = height * (land ? 0.5 : 0.52)
        floor = height * (land ? 0.93 : 0.94)
        wreath(out, far, width * 0.5, shelf - (height * (land ? 0.2 : 0.17)), [width, height].min * (land ? 0.13 : 0.15))
        # The chimney breast, its opening, and the hearth.
        left = width * (land ? 0.2 : 0.06)
        right = width - left
        post = (right - left) * (land ? 0.13 : 0.16)
        opening = shelf + ((floor - shelf) * 0.22)
        # The firebox's sooty back, so only the fire lights it.
        out << Fan.new(color: Color.hex("#0d0a07"), points: [[left + post, opening], [right - post, opening], [right - post, floor], [left + post, floor]])
        out << Fan.new(color: far, points: [[left, shelf], [left + post, shelf], [left + post, floor], [left, floor]])
        out << Fan.new(color: far, points: [[right - post, shelf], [right, shelf], [right, floor], [right - post, floor]])
        out << Fan.new(color: far, points: [[left, shelf], [right, shelf], [right, opening], [left, opening]])
        arch_r = (right - left - (2 * post)) / 2
        steps = 14
        (0...steps).each do |i|
          a1 = Math::PI * i / steps
          a2 = Math::PI * (i + 1) / steps
          cx = width / 2.0
          rise = [arch_r * 0.28, (floor - opening) * 0.3].min
          y1 = opening + rise - (Math.sin(a1) * rise)
          y2 = opening + rise - (Math.sin(a2) * rise)
          x1 = cx - (Math.cos(a1) * arch_r)
          x2 = cx - (Math.cos(a2) * arch_r)
          out << Fan.new(color: far, points: [[x1, opening - 1], [x2, opening - 1], [x2, y2], [x1, y1]])
        end
        fire(out, width / 2.0, floor, arch_r, land)
        out << Fan.new(color: ink, points: [[0, floor], [width, floor], [width, height], [0, height]])
        out << Fan.new(color: ink, points: [[left - 14, floor - 8], [right + 14, floor - 8], [right + 14, floor + 2], [left - 14, floor + 2]])
        # The shelf itself, and what stands on it.
        out << Fan.new(color: ink, points: [[left - 18, shelf - 12], [right + 18, shelf - 12], [right + 18, shelf + 2], [left - 18, shelf + 2]])
        out << Fan.new(color: ink, points: [[left - 8, shelf + 2], [right + 8, shelf + 2], [right + 8, shelf + 8], [left - 8, shelf + 8]])
        nutcracker(out, ink, left + ((right - left) * 0.2), shelf - 12, land ? 1.5 : 1.1)
        candle(out, ink, left + ((right - left) * 0.3), shelf - 12, land ? 1.3 : 1.0, 0.6)
        candle(out, ink, left + ((right - left) * 0.7), shelf - 12, land ? 1.3 : 1.0, 0.9)
        candle(out, ink, left + ((right - left) * 0.78), shelf - 12, land ? 1.3 : 1.0, 0.65)
        garland(out, ink, left - 18, right + 18, shelf - 4, land ? 5 : 3)
        count = land ? 5 : 4
        count.times do |i|
          f = (i + 0.5) / count
          stocking(out, ink, left + (post * 0.4) + ((right - left - (post * 0.8)) * f), shelf + 6, land ? 1.35 : 1.15, i)
        end
        out
      end

      # A wreath on the wall: a ring of fir and a bow at its foot.
      def wreath(out, color, x, y, radius)
        r = Random.new(31)
        36.times do |i|
          a = Math::PI * 2 * i / 36
          at = [x + (Math.cos(a) * radius), y + (Math.sin(a) * radius)]
          to = [x + (Math.cos(a + 0.2) * radius), y + (Math.sin(a + 0.2) * radius)]
          out << segment(at, to, radius * 0.18, radius * 0.18, color)
          needles(out, color, at, to, radius * 0.16, r)
        end
        bow(out, color, x, y + radius + 4, radius * 0.32)
        out << segment([x - 3, y + radius + 6], [x - (radius * 0.18), y + (radius * 1.45)], 4, 2.5, color)
        out << segment([x + 3, y + radius + 6], [x + (radius * 0.2), y + (radius * 1.42)], 4, 2.5, color)
      end

      FLAME = [Color.hex("#ff9a3a", 0.3), Color.hex("#ffc060", 0.26)].freeze

      # Logs on a grate, and low flames over them, kept dim.
      def fire(out, x, floor, half, land)
        s = land ? 1.4 : 1.0
        14.times { |i| out << Dot.new(x:, y: floor - (half * 0.12), radius: half * (1.0 - (i * 0.065)), color: Color.hex("#c0581c", 0.028)) }
        [[-0.9, 0.6], [0.95, 0.5], [-0.25, 0.78], [0.4, 0.64], [0.0, 0.5]].each_with_index do |(dx, h), i|
          fx = x + (dx * half * 0.3)
          fh = half * h * (land ? 0.55 : 0.75)
          flame(out, FLAME[0], fx, floor - (8 * s), fh, fh * 0.34, (i.even? ? 1 : -1) * 0.12)
          flame(out, FLAME[1], fx + (fh * 0.02), floor - (8 * s), fh * 0.6, fh * 0.2, (i.even? ? 1 : -1) * 0.1)
        end
        ink = Color.hex("#030806")
        out << segment([x - (half * 0.62), floor - (12 * s)], [x + (half * 0.5), floor - (17 * s)], 13 * s, 13 * s, ink)
        out << segment([x - (half * 0.4), floor - (19 * s)], [x + (half * 0.62), floor - (10 * s)], 12 * s, 12 * s, ink)
        out << Fan.new(color: ink, points: [[x - (half * 0.7), floor - (4 * s)], [x + (half * 0.7), floor - (4 * s)], [x + (half * 0.7), floor], [x - (half * 0.7), floor]])
      end

      # One flame, a teardrop from its base at +x+, +y+, its tip bent by
      # +lean+.
      def flame(out, color, x, y, h, w, lean)
        side = (0..8).map do |i|
          t = i / 8.0
          half = w * Math.sin(Math::PI * (t**0.7)) * (1 - (t * 0.35))
          [half, y - (h * t), x + (lean * h * t * t)]
        end
        left = side.map { |half, py, cx| [cx - half, py] }
        right = side.reverse.map { |half, py, cx| [cx + half, py] }
        out << Fan.new(color:, points: [[x, y - (h * 0.3)], *left, *right, left.first])
      end

      # A nutcracker standing guard on the shelf at +x+, +y+: boots, legs,
      # a coat with a belt, arms at his sides, his head and tall hat.
      def nutcracker(out, color, x, y, s)
        out << Fan.new(color:, points: [[x - (8 * s), y], [x + (8 * s), y], [x + (8 * s), y - (4 * s)], [x - (8 * s), y - (4 * s)]])
        out << Fan.new(color:, points: [[x - (5.5 * s), y - (4 * s)], [x + (5.5 * s), y - (4 * s)], [x + (5 * s), y - (20 * s)], [x - (5 * s), y - (20 * s)]])
        out << Fan.new(color:, points: [[x - (6.5 * s), y - (19 * s)], [x + (6.5 * s), y - (19 * s)], [x + (6 * s), y - (36 * s)], [x - (6 * s), y - (36 * s)]])
        out << Fan.new(color:, points: [[x - (10 * s), y - (35 * s)], [x + (10 * s), y - (35 * s)], [x + (9 * s), y - (38 * s)], [x - (9 * s), y - (38 * s)]])
        out << segment([x - (8 * s), y - (35 * s)], [x - (9 * s), y - (22 * s)], 3.2 * s, 3.2 * s, color)
        out << segment([x + (8 * s), y - (35 * s)], [x + (9 * s), y - (22 * s)], 3.2 * s, 3.2 * s, color)
        out << Fan.new(color:, points: [[x - (5 * s), y - (37 * s)], [x + (5 * s), y - (37 * s)], [x + (5 * s), y - (46 * s)], [x - (5 * s), y - (46 * s)]])
        out << Fan.new(color:, points: [[x - (5.5 * s), y - (46 * s)], [x + (5.5 * s), y - (46 * s)], [x + (4.5 * s), y - (60 * s)], [x - (4.5 * s), y - (60 * s)]])
        out << Dot.new(x:, y: y - (61 * s), radius: 2 * s, color:)
      end

      # A candy cane's hook, from +top+, curling to +side+.
      def hook(out, color, top, radius, side, thick)
        cx = top[0] + (side * radius)
        6.times do |i|
          a1 = Math::PI * i / 6
          a2 = Math::PI * (i + 1) / 6
          p1 = [cx - (side * Math.cos(a1) * radius), top[1] - (Math.sin(a1) * radius)]
          p2 = [cx - (side * Math.cos(a2) * radius), top[1] - (Math.sin(a2) * radius)]
          out << segment(p1, p2, thick, thick, color)
          out << Dot.new(x: p2[0], y: p2[1], radius: thick / 2, color:)
        end
      end

      # A candle in a holder, its flame a dim glow.
      def candle(out, color, x, y, s, tall)
        h = 40 * s * tall
        out << Fan.new(color:, points: [[x - (9 * s), y], [x + (9 * s), y], [x + (5 * s), y - (6 * s)], [x - (5 * s), y - (6 * s)]])
        out << Fan.new(color:, points: [[x - (4.5 * s), y - (6 * s)], [x + (4.5 * s), y - (6 * s)], [x + (4.5 * s), y - (6 * s) - h], [x - (4.5 * s), y - (6 * s) - h]])
        tip = y - (6 * s) - h
        out << Dot.new(x:, y: tip - (7 * s), radius: 9 * s, color: Color.hex("#ffb050", 0.08))
        out << Fan.new(color: Color.hex("#ffc870", 0.3), points: [[x, tip - (11 * s)], [x + (2.6 * s), tip - (4 * s)], [x, tip - (1 * s)], [x - (2.6 * s), tip - (4 * s)]])
      end

      # A garland along the shelf's edge: swags of fir with dim lights.
      def garland(out, color, from, to, y, swags)
        r = Random.new(17)
        span = (to - from) / swags
        swags.times do |k|
          points = (0..10).map { |i| [from + (span * (k + (i / 10.0))), y + (Math.sin(Math::PI * i / 10.0) * span * 0.12)] }
          points.each_cons(2).with_index do |(a, b), i|
            out << segment(a, b, 7, 7, color)
            needles(out, color, a, b, 7, r)
            out << Dot.new(x: b[0], y: b[1] + 4, radius: 2.2, color: LIGHTS[(i + k) % LIGHTS.size]) if i.odd?
          end
        end
      end

      # A stocking hung from the shelf: its loop, a cuff, the leg and a foot
      # with its toe to the right, and the hook of a candy cane in its top.
      def stocking(out, color, x, top, s, index)
        out << segment([x, top - 2], [x, top + (6 * s)], 2, 2, color)
        out << Fan.new(color:, points: [[x - (15 * s), top + (6 * s)], [x + (15 * s), top + (6 * s)], [x + (15 * s), top + (19 * s)], [x - (15 * s), top + (19 * s)]])
        out << Fan.new(color:, points: [[x - (12 * s), top + (19 * s)], [x + (12 * s), top + (19 * s)], [x + (12 * s), top + (54 * s)], [x - (12 * s), top + (54 * s)]])
        out << Dot.new(x: x - (1 * s), y: top + (56 * s), radius: 12 * s, color:)
        out << Fan.new(color:, points: [[x, top + (44 * s)], [x + (20 * s), top + (50 * s)], [x + (26 * s), top + (58 * s)], [x + (20 * s), top + (67 * s)], [x - (2 * s), top + (68 * s)]])
        return if index.odd?

        base = [x + (5 * s), top + (6 * s)]
        tip = [x + (7 * s), top - (10 * s)]
        out << segment(base, tip, 3.6 * s, 3.6 * s, color)
        hook(out, color, tip, 5 * s, -1, 3.6 * s)
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

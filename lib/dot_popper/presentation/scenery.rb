# frozen_string_literal: true

module DotPopper
  module Presentation
    # What stands in a theme's night, as plain shapes in graphics units:
    # silhouettes of trees, hills, a crooked house, a fence, graves, bats,
    # the wood's trunks, fir boughs and presents, snowy rooftops and a
    # sleigh, a snowy yard, a mantel by the fire, a sleigh ride, a
    # kitchen, a farm at Thanksgiving, and the edge of a wood where turkeys
    # roost. It knows no drawing library; Shell::Scene bakes these once,
    # for the screen's size, into a canvas at the screen's own resolution.
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
        when :roost then roost(width, height)
        when :rooftops then rooftops(width, height)
        when :snowfield then snowfield(width, height)
        when :mantel then mantel(width, height)
        when :sleigh_ride then sleigh_ride(width, height)
        when :kitchen then kitchen(width, height)
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

      # Any simple polygon, cut into triangles by ear clipping, so an
      # outline need not be convex or a fan about one point.
      def poly(out, color, points)
        ring = points.dup
        ring.reverse! if area(ring).negative?
        guard = ring.size * ring.size
        while ring.size > 3 && guard.positive?
          guard -= 1
          ear = ring.each_index.find { |i| ear?(ring, i) }
          break unless ear

          out << Fan.new(color:, points: [ring[ear - 1], ring[ear], ring[(ear + 1) % ring.size]])
          ring.delete_at(ear)
        end
        out << Fan.new(color:, points: ring) if ring.size == 3
      end

      def area(ring)
        ring.each_with_index.sum do |(x1, y1), i|
          x2, y2 = ring[(i + 1) % ring.size]
          (x1 * y2) - (x2 * y1)
        end / 2.0
      end

      def ear?(ring, i)
        a = ring[i - 1]
        b = ring[i]
        c = ring[(i + 1) % ring.size]
        return false if cross(a, b, c) <= 0

        ring.none? { |q| !q.equal?(a) && !q.equal?(b) && !q.equal?(c) && inside?(q, a, b, c) }
      end

      def cross(a, b, c) = ((b[0] - a[0]) * (c[1] - a[1])) - ((b[1] - a[1]) * (c[0] - a[0]))

      def inside?(q, a, b, c) = cross(a, b, q) >= 0 && cross(b, c, q) >= 0 && cross(c, a, q) >= 0

      # An ellipse about +x+, +y+, turned by +angle+.
      def oval(out, color, x, y, rx, ry, angle = 0.0, steps = 20)
        c = Math.cos(angle)
        s = Math.sin(angle)
        ring = (0...steps).map do |i|
          t = Math::PI * 2 * i / steps
          px = Math.cos(t) * rx
          py = Math.sin(t) * ry
          [x + (c * px) - (s * py), y + (s * px) + (c * py)]
        end
        out << Fan.new(color:, points: [[x, y], *ring, ring.first])
      end

      # A limb through +points+, +w1+ wide at its root and +w2+ at its tip,
      # with round joints.
      def limb(out, color, points, w1, w2)
        n = points.size - 1
        points.each_cons(2).with_index do |(a, b), i|
          wa = w1 + ((w2 - w1) * i / n)
          wb = w1 + ((w2 - w1) * (i + 1) / n)
          out << segment(a, b, wa, wb, color)
          out << Dot.new(x: b[0], y: b[1], radius: wb / 2.0, color:) if i < n - 1
        end
      end

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

      # Snowy rooftops on Christmas Eve: a far street of houses, near
      # houses with snow on their roofs, chimneys and lit windows, two
      # snowy firs, and Santa's sleigh going over.
      def rooftops(width, height)
        out = []
        land = width > height
        far = Color.hex("#101a3a")
        near = Color.hex("#03050e")
        snow_far = Color.hex("#2e3d70")
        snow_near = Color.hex("#28345e")
        lamp = Color.hex("#8a6a34", 0.55)
        base = height * (land ? 0.8 : 0.84)
        ground = height * (land ? 0.9 : 0.92)
        firs = [[width * (land ? 0.07 : 0.1), land ? 170 : 110], [width * (land ? 0.95 : 0.93), land ? 110 : 74]]
        x = -10.0
        r = Random.new(23)
        while x < width
          w = r.rand(0.8..1.3) * (land ? 70 : 46)
          townhouse(out, far, snow_far, lamp, x, base + r.rand(0.0..8.0), w, r.rand(0.5..0.9) * w, r, 0.35)
          x += w + r.rand(-6.0..4.0)
        end
        out << Fan.new(color: far, points: [[0, base], [width, base], [width, ground], [0, ground]])
        x = -20.0
        r = Random.new(41)
        while x < width
          w = r.rand(0.9..1.4) * (land ? 130 : 90)
          townhouse(out, near, snow_near, lamp, x, ground, w, r.rand(0.35..0.6) * w, r, 0.8, firs)
          x += w + r.rand(4.0..20.0)
        end
        out << Fan.new(color: Color.hex("#10183a"), points: [[0, ground], [width, ground], [width, height], [0, height]])
        out << Fan.new(color: Color.hex("#1a2650"), points: [[0, ground], [width, ground], [width, ground + 3], [0, ground + 3]])
        snow_fir(out, near, Color.hex("#34457a"), firs[0][0], ground + 6, height * (land ? 0.55 : 0.42), firs[0][1], Random.new(3))
        snow_fir(out, near, Color.hex("#34457a"), firs[1][0], ground + 6, height * (land ? 0.36 : 0.27), firs[1][1], Random.new(8))
        sleigh(out, Color.hex("#060a1c"), width * 0.88, height * (land ? 0.11 : 0.125), land ? 1.9 : 1.15)
        out
      end

      # A house seen from the street, its gable end toward us: walls, a
      # roof under a layer of snow, a chimney, and windows lit or dark,
      # each with its cross of glazing bars, on one sill line. No window is
      # put where one of +firs+ would cover it.
      def townhouse(out, color, snow, lamp, x, ground, w, h, random, lit, firs = [])
        roof = h * 0.55
        eave = ground - h
        out << Fan.new(color:, points: [[x, ground + 4], [x + w, ground + 4], [x + w, eave], [x, eave]])
        cx = x + (w * random.rand(0.62..0.76))
        top = eave - (roof * 0.95)
        out << Fan.new(color:, points: [[cx, eave - (roof * 0.2)], [cx + (w * 0.11), eave - (roof * 0.2)], [cx + (w * 0.11), top], [cx, top]])
        out << Fan.new(color: snow, points: [[cx - 1.5, top], [cx + (w * 0.11) + 1.5, top], [cx + (w * 0.11) + 1, top - 3], [cx - 1, top - 3]])
        out << Fan.new(color:, points: [[x + (w / 2), eave - roof], [x + w + (w * 0.06), eave + 2], [x - (w * 0.06), eave + 2]])
        t = [w * 0.05, 3.0].max
        peak = [x + (w / 2), eave - roof - (t * 0.6)]
        [[x - (w * 0.07), eave + 2], [x + w + (w * 0.07), eave + 2]].each do |foot|
          out << Fan.new(color: snow, points: [peak, foot, [foot[0], foot[1] - t], [peak[0], peak[1] - t]])
        end
        sill = ground - (h * 0.42)
        pane = w * 0.13
        spots = w > 70 ? [0.27, 0.73] : [0.5]
        spots.each do |f|
          wx = x + (w * f)
          next if firs.any? { |fx, fw| (wx - fx).abs < (fw * 0.55) + pane }

          glass = random.rand < lit ? lamp : Color.hex("#0b1124")
          out << Fan.new(color: glass, points: [[wx - (pane / 2), sill], [wx + (pane / 2), sill], [wx + (pane / 2), sill - (pane * 1.25)], [wx - (pane / 2), sill - (pane * 1.25)]])
          out << segment([wx, sill], [wx, sill - (pane * 1.25)], 1.2, 1.2, color)
          out << segment([wx - (pane / 2), sill - (pane * 0.62)], [wx + (pane / 2), sill - (pane * 0.62)], 1.2, 1.2, color)
        end
      end

      # A fir under snow: a trunk, then tiers of boughs, wide at the foot
      # and narrowing to the top, each tier's edge a row of drooping
      # bough tips, and snow lying on most of them.
      def snow_fir(out, color, snow, x, ground, h, w, random)
        out << Fan.new(color:, points: [[x - (w * 0.05), ground], [x + (w * 0.05), ground], [x + (w * 0.05), ground - (h * 0.12)], [x - (w * 0.05), ground - (h * 0.12)]])
        tiers = 8
        tiers.times do |i|
          f = i.to_f / tiers
          bottom = ground - (h * 0.08) - (h * 0.8 * f)
          half = w * 0.6 * (1 - (f * 0.92)) * random.rand(0.92..1.05)
          apex = [x, bottom - (h * (0.2 - (f * 0.06)))]
          count = [5 - (i / 2), 2].max
          cuts = (0..count).map { |k| -1.0 + (2.0 * k / count) + (k.zero? || k == count ? 0 : random.rand(-0.12..0.12)) }
          sag = h * 0.016
          edge = []
          cuts.each_cons(2) do |c1, c2|
            6.times do |j|
              t = j / 6.0
              q = c1 + ((c2 - c1) * t)
              edge << [x + (q * half), bottom + (q.abs * sag) + (Math.sin(Math::PI * t) * sag * 0.9) - ((1 - Math.sin(Math::PI * t)) * sag * 0.3)]
            end
          end
          edge << [x + half, bottom + sag]
          poly(out, color, [apex, *edge])
          cuts.each_cons(2) do |c1, c2|
            next if random.rand < 0.2

            lift = sag * random.rand(0.6..0.9)
            depth = [sag * random.rand(0.8..1.2), 1.8].max
            arc = (0..8).map do |j|
              t = 0.08 + (j / 8.0 * 0.84)
              q = c1 + ((c2 - c1) * t)
              dome = Math.sin(Math::PI * (j / 8.0))
              [x + (q * half), bottom + (q.abs * sag) + (sag * 0.5) - lift, dome]
            end
            under = arc.map { |px, py, _| [px, py] }
            over = arc.reverse.map { |px, py, dome| [px, py - (depth * Math.sqrt(dome))] }
            poly(out, snow, [*under, *over])
          end
        end
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

      # Santa's sleigh and his team, flying up and away to the left: the
      # sleigh's runners curl up at its front, toward the team; Santa sits
      # in it with his sack behind him and the reins in his hands; four
      # reindeer ahead in single file, rising, each in a flying gallop,
      # forelegs tucked and hind legs stretched back.
      def sleigh(out, color, x, y, s)
        tilt = 0.08
        at = ->(px, py) { [x + (s * ((Math.cos(tilt) * px) - (Math.sin(tilt) * py))), y + (s * ((Math.sin(tilt) * px) + (Math.cos(tilt) * py)))] }
        # The team in single file along a rising curve, the harness
        # running beneath them from the sleigh to the leader.
        team = [[-50, 0, 0.9], [-95, -4, 0.2], [-140, -10, 0.65], [-185, -18, 0.0]]
        harness = [at.call(-7, -14), *team.map { |hx, hy, _| at.call(hx - 8, hy - 2) }]
        harness.each_cons(2) { |a, b| out << segment(a, b, 0.9, 0.9, color) }
        team.each { |hx, hy, gait| reindeer(out, color, ->(px, py) { at.call(hx + px, hy + py) }, gait, s) }
        # Runners on two struts, curling up at the front.
        runner = [[18, 7], [-14, 7], [-19, 5], [-22, 1], [-22, -3], [-19, -5], [-17, -3]]
        limb(out, color, runner.map { at.call(*it) }, 1.6 * s, 1.3 * s)
        [[-8, 7, -7, 2], [10, 7, 9, 2]].each { |a, b, c, d| out << segment(at.call(a, b), at.call(c, d), 1.3 * s, 1.3 * s, color) }
        # The sleigh's body: a high back, a low middle, and a front that
        # sweeps up and over into a scroll.
        body = [[16, 2], [-10, 2], [-14, -1], [-17, -6], [-18, -11], [-16, -15], [-12, -16], [-10, -13], [-12, -10],
                [-9, -8], [2, -8], [8, -10], [13, -16], [17, -17], [18, -12], [18, -4]]
        poly(out, color, body.map { at.call(*it) })
        # Santa: a round body, an arm out to the reins, his head and a hat
        # flopped back with its bobble.
        oval(out, color, *at.call(3, -14), 6 * s, 7 * s, tilt)
        limb(out, color, [at.call(0, -15), at.call(-4, -13), at.call(-7, -14)], 2.6 * s, 2.0 * s)
        oval(out, color, *at.call(4, -22.5), 3.4 * s, 3.4 * s)
        poly(out, color, [at.call(0.5, -23.5), at.call(2, -27), at.call(6, -29), at.call(11, -27.5), at.call(7.5, -25.5), at.call(7.5, -23.5)])
        oval(out, color, *at.call(11.5, -27), 1.5 * s, 1.5 * s)
        # His sack, its neck tied, behind him.
        oval(out, color, *at.call(12.5, -17), 5 * s, 6 * s, tilt)
        poly(out, color, [at.call(10.5, -22), at.call(11, -25), at.call(10, -27), at.call(14, -27), at.call(13.5, -24), at.call(14, -22)])
      end

      # A reindeer facing left in a flying gallop, placed by +at+; +gait+
      # from 0 to 1 moves its legs a little, so no two are the same.
      def reindeer(out, color, at, gait, s)
        oval(out, color, *at.call(0, 0), 11 * s, 4.6 * s, -0.08)
        oval(out, color, *at.call(-8, -0.5), 4.6 * s, 4.6 * s)
        poly(out, color, [at.call(-10, -2), at.call(-12, -5), at.call(-17, -8.5), at.call(-20, -9.5), at.call(-18.5, -5), at.call(-13, 1)])
        poly(out, color, [at.call(-18, -10.5), at.call(-21.5, -11), at.call(-26, -8.8), at.call(-26.3, -7.2), at.call(-22.5, -6.8), at.call(-18.5, -6.5)])
        poly(out, color, [at.call(-18.5, -10), at.call(-15.5, -12.5), at.call(-17.3, -8.8)])
        limb(out, color, [at.call(-19.5, -10.5), at.call(-18.5, -14.5), at.call(-16, -18), at.call(-13, -20)], 1.3 * s, 0.8 * s)
        limb(out, color, [at.call(-18.5, -14.5), at.call(-21.5, -17)], 0.9 * s, 0.7 * s)
        limb(out, color, [at.call(-16, -18), at.call(-17.5, -21.5)], 0.9 * s, 0.7 * s)
        f = gait * 2.0
        limb(out, color, [at.call(-9, 3), at.call(-13 + f, 8), at.call(-17 + f, 6.5)], 2.4 * s, 1.4 * s)
        limb(out, color, [at.call(-6, 3), at.call(-8 - f, 9), at.call(-12 - f, 9.5)], 2.4 * s, 1.4 * s)
        limb(out, color, [at.call(7, 2), at.call(12, 6 + f), at.call(19, 7.5 + f)], 3.0 * s, 1.4 * s)
        limb(out, color, [at.call(9, 2.5), at.call(13, 7.5 - f), at.call(18 - f, 11)], 3.0 * s, 1.4 * s)
        poly(out, color, [at.call(10, -3), at.call(13.5, -5.5), at.call(12.5, -2)])
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
      # a belted coat, arms at his sides, his head and tall hat.
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

      # A candle in a candlestick, its flame a dim glow.
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

      # A sleigh ride through the snow at night: snowy hills at three
      # depths, firs on them, a split-rail fence, and a one-horse open
      # sleigh with its lantern going along the middle hill.
      def sleigh_ride(width, height)
        out = []
        land = width > height
        far = Color.hex("#2c2052")
        mid = Color.hex("#1a1336")
        near = Color.hex("#0a0818")
        snow_far = Color.hex("#43357a")
        snow_mid = Color.hex("#2e2662")
        snow_near = Color.hex("#1e1a48")
        ridge_far = ->(f) { height * ((land ? 0.66 : 0.72) + (0.04 * Math.sin((f * 5.0) + 1.0)) + (0.015 * Math.sin(f * 13))) }
        hill_strip(out, far, width, height, &ridge_far)
        (land ? 16 : 9).times do |i|
          r = Random.new(800 + i)
          f = (i + r.rand(0.0..0.8)) / (land ? 16 : 9)
          snowy_fir(out, far, snow_far, width * f, ridge_far.call(f) + 3, r.rand(30.0..60.0), r.rand(16.0..26.0)) if r.rand < 0.75
        end
        ridge_mid = ->(f) { height * ((land ? 0.78 : 0.82) + (0.035 * Math.sin((f * 3.2) + 2.4))) }
        hill_strip(out, mid, width, height, &ridge_mid)
        hill_line(out, snow_mid, width, ridge_mid)
        f = 0.0
        while f < 1.0
          rail(out, mid, width * f, ridge_mid.call(f), width * (land ? 0.06 : 0.1), ridge_mid.call(f + (land ? 0.06 : 0.1)) - ridge_mid.call(f))
          f += land ? 0.06 : 0.1
        end
        sx = land ? 0.36 : 0.42
        open_sleigh(out, mid, width * sx, ridge_mid.call(sx) + 2, land ? 2.3 : 1.6)
        ridge_near = ->(f) { height * ((land ? 0.9 : 0.92) + (0.025 * Math.sin((f * 2.2) + 4.0))) }
        hill_strip(out, near, width, height, &ridge_near)
        hill_line(out, snow_near, width, ridge_near)
        snowy_fir(out, near, snow_near, width * (land ? 0.06 : 0.08), ridge_near.call(0.06) + 8, height * (land ? 0.72 : 0.62), land ? 150 : 110)
        snowy_fir(out, near, snow_near, width * (land ? 0.17 : 0.27), ridge_near.call(0.16) + 8, height * (land ? 0.36 : 0.26), land ? 80 : 56)
        snowy_fir(out, near, snow_near, width * (land ? 0.93 : 0.92), ridge_near.call(0.93) + 8, height * (land ? 0.58 : 0.46), land ? 130 : 90)
        out
      end

      # Snow along a hill's crest.
      def hill_line(out, snow, width, ridge, steps = 48)
        (0...steps).each do |i|
          a = [width * i / steps.to_f, ridge.call(i / steps.to_f) + 1.5]
          b = [width * (i + 1) / steps.to_f, ridge.call((i + 1) / steps.to_f) + 1.5]
          out << segment(a, b, 3.0, 3.0, snow)
        end
      end

      # One bay of a split-rail fence: a post and two rails.
      def rail(out, color, x, ground, span, rise)
        out << Fan.new(color:, points: [[x - 2.5, ground + 4], [x + 2.5, ground + 4], [x + 2, ground - 26], [x - 2, ground - 26]])
        out << segment([x, ground - 20], [x + span, ground - 20 + rise], 3.0, 3.0, color)
        out << segment([x, ground - 9], [x + span, ground - 9 + rise], 3.0, 3.0, color)
      end

      # A horse drawing an open sleigh to the right, a driver in it, and a
      # lantern hung at its front.
      def open_sleigh(out, color, x, ground, s)
        at = ->(a, b) { [x + (a * s), ground + (b * s)] }
        # The sleigh: a runner curling up at the front, the box, its back.
        runner = [[-30, -2], [10, -2], [16, -5], [18, -11], [15, -14], [13, -11], [14, -7], [10, -5], [-30, -5]]
        runner.each_cons(2) { |a, b| out << segment(at.call(*a), at.call(*b), 2.2 * s, 2.2 * s, color) }
        out << segment(at.call(-24, -5), at.call(-24, -10), 2 * s, 2 * s, color)
        out << segment(at.call(4, -5), at.call(4, -10), 2 * s, 2 * s, color)
        out << Fan.new(color:, points: [at.call(-28, -10), at.call(8, -10), at.call(12, -18), at.call(-18, -18), at.call(-30, -26), at.call(-32, -20)])
        # The driver, and his reins.
        out << Fan.new(color:, points: [at.call(-16, -18), at.call(-6, -18), at.call(-7, -31), at.call(-15, -31)])
        out << Dot.new(x: at.call(-11, -35)[0], y: at.call(-11, -35)[1], radius: 4.5 * s, color:)
        out << Fan.new(color:, points: [at.call(-16, -38), at.call(-6, -38), at.call(-8, -43), at.call(-14, -43)])
        out << segment(at.call(-7, -27), at.call(26, -26), 0.8 * s, 0.8 * s, color)
        # Shafts to the horse.
        out << segment(at.call(10, -12), at.call(30, -18), 1.6 * s, 1.6 * s, color)
        # The horse, trotting.
        out << segment(at.call(28, -24), at.call(52, -25), 13 * s, 12 * s, color)
        out << Dot.new(x: at.call(28, -24)[0], y: at.call(28, -24)[1], radius: 6.5 * s, color:)
        out << Dot.new(x: at.call(52, -25)[0], y: at.call(52, -25)[1], radius: 6 * s, color:)
        out << segment(at.call(53, -28), at.call(60, -42), 7 * s, 5 * s, color)
        out << segment(at.call(60, -42), at.call(68, -38), 5 * s, 3.4 * s, color)
        out << segment(at.call(59, -46), at.call(61, -50), 1.5 * s, 1 * s, color)
        [[31, 0, 25, -2], [36, -2, 37, 0], [48, -1, 55, -6], [53, -2, 50, 0]].each_with_index do |(kx, ky, fx, fy), i|
          hip = at.call(i < 2 ? 30 + (i * 4) : 50 + ((i - 2) * 3), -20)
          knee = at.call(kx, -10 + ky)
          out << segment(hip, knee, 3 * s, 2.4 * s, color)
          out << segment(knee, at.call(fx, fy), 2.4 * s, 2 * s, color)
        end
        out << segment(at.call(22, -26), at.call(16, -14), 3 * s, 1.5 * s, color)
        # The lantern, dimly lit.
        out << segment(at.call(17, -14), at.call(17, -19), 0.8 * s, 0.8 * s, color)
        out << Dot.new(x: at.call(17, -12)[0], y: at.call(17, -12)[1], radius: 7 * s, color: Color.hex("#ffb050", 0.1))
        out << Dot.new(x: at.call(17, -12)[0], y: at.call(17, -12)[1], radius: 2 * s, color: Color.hex("#ffc870", 0.45))
      end

      # A kitchen on a snowy night: a window onto the snow with a garland
      # over it, cupboards, and on the counter a gingerbread house with
      # icing on its roof, a cookie jar and a rolling pin, and one
      # gingerbread man running off along the counter.
      def kitchen(width, height)
        out = []
        land = width > height
        far = Color.hex("#141c30")
        ink = Color.hex("#060910")
        icing = Color.hex("#343c58")
        pane = Color.hex("#1a2440")
        counter = height * (land ? 0.8 : 0.84)
        # The window, its panes, and snow on their sills.
        ww = width * (land ? 0.3 : 0.5)
        wx = (width - ww) / 2
        wy = height * (land ? 0.1 : 0.14)
        wh = height * (land ? 0.42 : 0.28)
        out << Fan.new(color: far, points: [[wx - 14, wy - 14], [wx + ww + 14, wy - 14], [wx + ww + 14, wy + wh + 14], [wx - 14, wy + wh + 14]])
        [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]].each do |i, j|
          px = wx + (i * ww / 3) + 4
          py = wy + (j * wh / 2) + 4
          pw = (ww / 3) - 8
          ph = (wh / 2) - 8
          out << Fan.new(color: pane, points: [[px, py], [px + pw, py], [px + pw, py + ph], [px, py + ph]])
          drift = ->(f) { py + ph - (ph * (0.1 + (0.05 * Math.sin((f * 6) + i + (j * 2))))) }
          (0...10).each do |k|
            x1 = px + (pw * k / 10.0)
            x2 = px + (pw * (k + 1) / 10.0)
            out << Fan.new(color: icing, points: [[x1, drift.call(k / 10.0)], [x2, drift.call((k + 1) / 10.0)], [x2, py + ph], [x1, py + ph]])
          end
        end
        out << Fan.new(color: far, points: [[wx - 24, wy + wh + 8], [wx + ww + 24, wy + wh + 8], [wx + ww + 24, wy + wh + 20], [wx - 24, wy + wh + 20]])
        out << segment([wx - 24, wy + wh + 8], [wx + ww + 24, wy + wh + 8], 4, 4, icing)
        garland(out, far, wx - 24, wx + ww + 24, wy - 10, land ? 3 : 2)
        # Cupboards at the sides, high up.
        cw = width * (land ? 0.22 : 0.16)
        [[0, cw], [width - cw, width]].each do |x1, x2|
          out << Fan.new(color: far, points: [[x1, -10], [x2, -10], [x2, height * (land ? 0.36 : 0.3)], [x1, height * (land ? 0.36 : 0.3)]])
        end
        # The counter.
        out << Fan.new(color: ink, points: [[0, counter], [width, counter], [width, height], [0, height]])
        out << Fan.new(color: ink, points: [[-5, counter - 8], [width + 5, counter - 8], [width + 5, counter + 2], [-5, counter + 2]])
        s = land ? 1.5 : 1.0
        gingerbread_house(out, ink, icing, width * (land ? 0.3 : 0.3), counter - 8, s * 1.25)
        cookie_jar(out, ink, width * (land ? 0.72 : 0.82), counter - 8, s)
        rolling_pin(out, ink, width * (land ? 0.55 : 0.62), counter - 8, s)
        runner(out, ink, width * (land ? 0.86 : 0.6), counter - 8, s * 0.9)
        out
      end

      # A gingerbread house: walls, a door and windows, and a roof with
      # icing dripping from its eaves and snow along its ridge.
      def gingerbread_house(out, color, icing, x, ground, s)
        w = 46 * s
        h = 30 * s
        out << Fan.new(color:, points: [[x - w, ground], [x + w, ground], [x + w, ground - h], [x - w, ground - h]])
        out << Fan.new(color:, points: [[x, ground - h - (40 * s)], [x + w + (10 * s), ground - h + (4 * s)], [x - w - (10 * s), ground - h + (4 * s)]])
        out << Fan.new(color:, points: [[x + (18 * s), ground - h - (26 * s)], [x + (28 * s), ground - h - (18 * s)], [x + (28 * s), ground - h - (40 * s)], [x + (18 * s), ground - h - (40 * s)]])
        # Icing along both eaves, in drips.
        [-1, 1].each do |side|
          a = [x, ground - h - (40 * s)]
          b = [x + (side * (w + (10 * s))), ground - h + (4 * s)]
          out << segment(a, b, 3.5 * s, 3.5 * s, icing)
          6.times do |k|
            t = (k + 0.5) / 6
            at = [a[0] + ((b[0] - a[0]) * t), a[1] + ((b[1] - a[1]) * t)]
            out << Dot.new(x: at[0], y: at[1] + (3 * s), radius: 2.6 * s, color: icing)
          end
        end
        out << segment([x - w, ground - h + (6 * s)], [x + w, ground - h + (6 * s)], 2.2 * s, 2.2 * s, icing)
        out << Fan.new(color: Color.hex("#8a5a24", 0.5), points: [[x - (6 * s), ground], [x + (6 * s), ground], [x + (6 * s), ground - (16 * s)], [x - (6 * s), ground - (16 * s)]])
        [-1, 1].each do |side|
          wx = x + (side * 26 * s)
          out << Fan.new(color: Color.hex("#8a5a24", 0.5), points: [[wx - (6 * s), ground - (12 * s)], [wx + (6 * s), ground - (12 * s)], [wx + (6 * s), ground - (22 * s)], [wx - (6 * s), ground - (22 * s)]])
        end
        [-34, -20, 20, 34].each { |dx| out << Dot.new(x: x + (dx * s), y: ground - (3 * s), radius: 3 * s, color: icing) }
      end

      # A cookie jar with a knobbed lid.
      def cookie_jar(out, color, x, ground, s)
        out << Fan.new(color:, points: [[x - (17 * s), ground], [x + (17 * s), ground], [x + (21 * s), ground - (20 * s)], [x + (17 * s), ground - (40 * s)], [x - (17 * s), ground - (40 * s)], [x - (21 * s), ground - (20 * s)]])
        out << Fan.new(color:, points: [[x - (19 * s), ground - (40 * s)], [x + (19 * s), ground - (40 * s)], [x + (14 * s), ground - (47 * s)], [x - (14 * s), ground - (47 * s)]])
        out << Dot.new(x:, y: ground - (50 * s), radius: 5 * s, color:)
      end

      # A rolling pin lying on the counter, its handles out at each end.
      def rolling_pin(out, color, x, ground, s)
        out << segment([x - (24 * s), ground - (6 * s)], [x + (24 * s), ground - (6 * s)], 12 * s, 12 * s, color)
        out << segment([x - (38 * s), ground - (6 * s)], [x + (38 * s), ground - (6 * s)], 4 * s, 4 * s, color)
        [-1, 1].each { |side| out << Dot.new(x: x + (side * 39 * s), y: ground - (6 * s), radius: 3.2 * s, color:) }
      end

      # A gingerbread man running off to the right: head, body, arms
      # swinging and legs mid-stride.
      def runner(out, color, x, ground, s)
        out << Dot.new(x: x + (3 * s), y: ground - (40 * s), radius: 7 * s, color:)
        out << segment([x + (1 * s), ground - (32 * s)], [x - (1 * s), ground - (16 * s)], 12 * s, 11 * s, color)
        out << segment([x, ground - (28 * s)], [x + (12 * s), ground - (34 * s)], 6 * s, 5 * s, color)
        out << segment([x - (1 * s), ground - (28 * s)], [x - (12 * s), ground - (22 * s)], 6 * s, 5 * s, color)
        out << segment([x, ground - (16 * s)], [x + (11 * s), ground - (3 * s)], 6.5 * s, 5.5 * s, color)
        out << segment([x - (2 * s), ground - (16 * s)], [x - (12 * s), ground - (6 * s)], 6.5 * s, 5.5 * s, color)
        [[x + (12 * s), ground - (34 * s)], [x - (12 * s), ground - (22 * s)], [x + (11 * s), ground - (3 * s)], [x - (12 * s), ground - (6 * s)]].each do |hx, hy|
          out << Dot.new(x: hx, y: hy, radius: 2.8 * s, color:)
        end
      end

      # The edge of a wood at nightfall, where turkeys roost: a far line of
      # trees, a field with round hay bales and a rail fence, and two great
      # oaks with turkeys gone up into their limbs for the night.
      def roost(width, height)
        out = []
        land = width > height
        far_c = Color.hex("#221a30")
        mid_c = Color.hex("#140f1e")
        ink = Color.hex("#07060d")
        far = ->(f) { height * ((land ? 0.76 : 0.8) + (0.02 * Math.sin((f * 4) + 0.5)) + (0.008 * Math.sin(f * 15))) }
        hill_strip(out, far_c, width, height, &far)
        r = Random.new(88)
        x = 0.0
        while x < width
          out << Dot.new(x:, y: far.call(x / width) - 3, radius: r.rand(8.0..16.0) * (land ? 1.2 : 1.0), color: far_c)
          x += r.rand(9.0..16.0)
        end
        field = ->(f) { height * ((land ? 0.86 : 0.885) + (0.01 * Math.sin((f * 2.2) + 1.3))) }
        hill_strip(out, mid_c, width, height, &field)
        [[0.42, 1.0], [0.52, 0.8], [0.66, 0.9], [0.78, 0.7]].each do |f, size|
          next if !land && f > 0.7

          rad = size * (land ? 15 : 12)
          out << Dot.new(x: width * f, y: field.call(f) - (rad * 0.85), radius: rad, color: mid_c)
        end
        near = ->(f) { height * ((land ? 0.92 : 0.935) + (0.012 * Math.sin((f * 3.1) + 0.2))) }
        hill_strip(out, ink, width, height, &near)
        fence(out, ink, width * 0.3, width, near, width)
        [[land ? 0.12 : 0.16, land ? 0.24 : 0.2, land ? 46 : 34, -0.08, 5], [land ? 0.9 : 0.92, land ? 0.17 : 0.13, land ? 34 : 24, -0.3, 61]].each do |f, reach, w, lean, rs|
          forks = []
          oak(out, ink, width * f, near.call(f) + 8, (-Math::PI / 2) + lean, height * reach, w, 5, Random.new(rs), forks)
          forks.select { |_, _, depth| depth.between?(3, 4) }.each_with_index do |(bx, by, _), i|
            roosting_turkey(out, ink, bx, by, land ? 2.1 : 1.6, i.even? ? 1 : -1) if i.even?
          end
        end
        out
      end

      # A turkey asleep on a limb: a round body, its tail hanging, its head
      # sunk in its shoulders.
      def roosting_turkey(out, color, x, y, s, facing)
        out << Fan.new(color:, points: [[x - (facing * 4 * s), y - (4 * s)], [x - (facing * 9 * s), y - (2 * s)], [x - (facing * 13 * s), y + (9 * s)],
                                        [x - (facing * 7 * s), y + (11 * s)], [x - (facing * 2 * s), y + (2 * s)]])
        out << Dot.new(x:, y: y - (6 * s), radius: 7 * s, color:)
        out << Dot.new(x: x + (facing * 6 * s), y: y - (11 * s), radius: 3 * s, color:)
        out << segment([x + (facing * 2 * s), y], [x + (facing * 2 * s), y + (3 * s)], 1.2 * s, 1.2 * s, color)
      end

      # A farm at dusk on Thanksgiving, at three depths: far hills and a
      # line of trees; the farmhouse, its windows lit for dinner, with
      # smoke from its chimney, and a barn and silo; and near, a tall oak
      # with its last leaves, pumpkins, a split-rail fence, and geese
      # going over.
      def farm(width, height)
        out = []
        land = width > height
        far_c = Color.hex("#2a1726")
        mid_c = Color.hex("#150c17")
        ink = Color.hex("#07050c")
        lamp = Color.hex("#c8843a", 0.62)
        far = ->(f) { height * ((land ? 0.73 : 0.77) + (0.025 * Math.sin((f * 5) + 1)) + (0.008 * Math.sin(f * 17))) }
        hill_strip(out, far_c, width, height, &far)
        r = Random.new(70)
        x = 0.0
        while x < width
          f = x / width
          out << Dot.new(x:, y: far.call(f) - 2, radius: r.rand(6.0..12.0) * (land ? 1.2 : 1.0), color: far_c) if f < 0.3 || f > 0.55
          x += r.rand(8.0..15.0)
        end
        mid = ->(f) { height * ((land ? 0.83 : 0.855) + (0.012 * Math.sin((f * 3) + 0.4))) }
        hill_strip(out, mid_c, width, height, &mid)
        hx = width * (land ? 0.16 : 0.2)
        farmhouse(out, mid_c, lamp, hx, mid.call(hx / width) + 4, land ? 1.8 : 1.1)
        bx = width * (land ? 0.42 : 0.6)
        barn(out, mid_c, lamp, bx, mid.call(bx / width) + 4, land ? 1.6 : 1.0)
        near = ->(f) { height * ((land ? 0.9 : 0.915) + (0.014 * Math.sin((f * 2.6) + 0.6))) }
        hill_strip(out, ink, width, height, &near)
        [[0.06, 9], [0.12, 6.5], [0.3, 8], [0.36, 5.5]].each_with_index do |(f, size), i|
          next if !land && i == 3

          pumpkin(out, ink, width * f, near.call(f) + 2, size * (land ? 1.3 : 1.0))
        end
        fence(out, ink, 0, width * (land ? 0.4 : 0.38), near, width)
        ox = land ? 0.88 : 0.87
        oak(out, ink, width * ox, near.call(ox) + 8, -Math::PI / 2 - 0.1, height * (land ? 0.2 : 0.17), land ? 40 : 30, 5, Random.new(31))
        geese = land ? [0.3, 0.2] : [0.36, 0.3]
        [[0, 0], [-1, -1], [1, -1], [-2, -2], [2, -2], [-3, -3]].each do |i, j|
          at = [width * geese[0] + (i * 16 * (land ? 1.2 : 1.0)), height * geese[1] + (j * -9 * (land ? 1.2 : 1.0))]
          goose(out, Color.hex("#100a18"), at, land ? 1.5 : 1.2)
        end
        out
      end

      # A farmhouse: two storeys, a gable roof, a porch, a chimney with
      # smoke, and windows lit warm.
      def farmhouse(out, color, lamp, x, ground, s)
        w = 62 * s
        h = 40 * s
        out << Fan.new(color:, points: [[x - (w / 2), ground], [x + (w / 2), ground], [x + (w / 2), ground - h], [x - (w / 2), ground - h]])
        out << Fan.new(color:, points: [[x, ground - h - (26 * s)], [x + (w / 2) + (5 * s), ground - h + (2 * s)], [x - (w / 2) - (5 * s), ground - h + (2 * s)]])
        cx = x + (14 * s)
        out << Fan.new(color:, points: [[cx, ground - h - (4 * s)], [cx + (7 * s), ground - h - (4 * s)], [cx + (7 * s), ground - h - (26 * s)], [cx, ground - h - (26 * s)]])
        smoke(out, cx + (3.5 * s), ground - h - (30 * s), 9 * s)
        out << Fan.new(color:, points: [[x - (w / 2) - (6 * s), ground - (15 * s)], [x + (w / 2) + (6 * s), ground - (15 * s)], [x + (w / 2) + (2 * s), ground - (19 * s)], [x - (w / 2) - (2 * s), ground - (19 * s)]])
        [[-20, -31], [-4, -31], [12, -31], [-20, -10], [12, -10]].each_with_index do |(wx, wy), i|
          next if i == 2

          a = [x + ((wx - 3) * s), ground + ((wy - 4.5) * s)]
          b = [x + ((wx + 3) * s), ground + ((wy + 4.5) * s)]
          out << Fan.new(color: lamp, points: [a, [b[0], a[1]], b, [a[0], b[1]]])
          out << segment([x + (wx * s), a[1]], [x + (wx * s), b[1]], 0.9 * s, 0.9 * s, color)
        end
      end

      # A barn with a gambrel roof and a hay door, and a silo beside it.
      def barn(out, color, lamp, x, ground, s)
        shape = [[-26, 0], [-26, -26], [-20, -42], [0, -52], [20, -42], [26, -26], [26, 0]]
        out << Fan.new(color:, points: [[x, ground - (25 * s)], *shape.map { |a, b| [x + (a * s), ground + (b * s)] }, [x + (shape.first[0] * s), ground + (shape.first[1] * s)]])
        out << Fan.new(color:, points: [[x + (30 * s), ground], [x + (44 * s), ground], [x + (44 * s), ground - (60 * s)], [x + (30 * s), ground - (60 * s)]])
        out << Dot.new(x: x + (37 * s), y: ground - (60 * s), radius: 7 * s, color:)
        out << Fan.new(color: lamp, points: [[x - (5 * s), ground - (38 * s)], [x + (5 * s), ground - (38 * s)], [x + (5 * s), ground - (30 * s)], [x - (5 * s), ground - (30 * s)]])
      end

      # A pumpkin on the ground: two lobes and a stem.
      def pumpkin(out, color, x, ground, size)
        out << Dot.new(x: x - (size * 0.42), y: ground - (size * 0.8), radius: size * 0.8, color:)
        out << Dot.new(x: x + (size * 0.42), y: ground - (size * 0.8), radius: size * 0.8, color:)
        out << Dot.new(x:, y: ground - (size * 0.85), radius: size * 0.88, color:)
        out << segment([x, ground - (size * 1.6)], [x + (size * 0.25), ground - (size * 2.15)], size * 0.28, size * 0.18, color)
      end

      # A split-rail fence along the ground from +x1+ to +x2+.
      def fence(out, color, x1, x2, ground, width)
        x = x1 + 6
        prev = nil
        while x < x2
          g = ground.call(x / width)
          out << Fan.new(color:, points: [[x - 2.2, g + 6], [x - 2.2, g - 22], [x + 2.2, g - 22], [x + 2.2, g + 6]])
          if prev
            out << segment([prev[0], prev[1] - 17], [x, g - 15], 2.4, 2.4, color)
            out << segment([prev[0], prev[1] - 8], [x, g - 6], 2.4, 2.4, color)
          end
          prev = [x, g]
          x += 30
        end
      end

      # A goose flying left: a body, a long neck, and its wings up.
      def goose(out, color, at, s)
        x, y = at
        out << segment([x - (9 * s), y], [x + (6 * s), y + (1 * s)], 3.2 * s, 2.0 * s, color)
        out << segment([x - (9 * s), y], [x - (15 * s), y - (1.5 * s)], 1.4 * s, 1.2 * s, color)
        out << segment([x - (2 * s), y], [x + (3 * s), y - (8 * s)], 2.2 * s, 0.8 * s, color)
        out << segment([x - (2 * s), y], [x + (1 * s), y + (6 * s)], 2.0 * s, 0.8 * s, color)
      end

      # An oak late in the fall: a broad canopy of crooked limbs, a few
      # leaves still on their tips.
      def oak(out, color, x, y, angle, length, width, depth, random, forks = nil)
        steps = 3
        points = [[x, y]]
        bent = angle
        steps.times do
          bent += normal(random, 0.25)
          points << [points.last[0] + (Math.cos(bent) * length / steps), points.last[1] + (Math.sin(bent) * length / steps)]
        end
        points.each_cons(2).with_index do |(a, b), i|
          w1 = width * (1 - (i.to_f / steps * 0.4))
          w2 = width * (1 - ((i + 1).to_f / steps * 0.4))
          out << segment(a, b, w1, w2, color)
          out << Dot.new(x: a[0], y: a[1], radius: w1 / 2.0, color:)
        end
        tip = points.last
        if depth.zero?
          random.rand(0..3).times do
            out << Dot.new(x: tip[0] + random.rand(-7.0..7.0), y: tip[1] + random.rand(-7.0..7.0), radius: random.rand(2.0..3.6), color:)
          end
          return
        end
        out << Dot.new(x: tip[0], y: tip[1], radius: width * 0.3, color:)
        forks << [tip[0], tip[1], depth] if forks
        spread = depth > 3 ? 1.1 : 0.8
        random.rand(3..4).times do
          oak(out, color, tip[0], tip[1], bent + random.rand(-spread..spread), length * random.rand(0.58..0.74), width * 0.55, depth - 1, random, forks)
        end
      end
    end
  end
end

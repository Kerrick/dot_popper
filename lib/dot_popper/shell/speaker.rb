# frozen_string_literal: true

module DotPopper
  module Shell
    # Plays the game's sounds, which the synthesizer makes when the game
    # starts. Each sound has a few voices, so quick taps overlap rather
    # than cut each other off. With no audio device, or muted, it plays
    # nothing and the game goes on. Muting is remembered in +store+.
    class Speaker
      VOICES = 4

      def initialize(patches, store:, volume: 1.0)
        @store = store
        @volume = volume
        @muted = store.read.to_s.strip == "muted"
        @voices = build(patches)
        @next = Hash.new(0)
      end

      def muted? = @muted

      def toggle_mute
        @muted = !@muted
        @store.write(@muted ? "muted" : "on")
        @voices.each_value { |voices| voices.each(&:stop) } if @muted
        @muted
      rescue StandardError
        @muted
      end

      def play(name, pitch: 1.0)
        return if @muted

        voices = @voices[name] or return
        voice = voices[@next[name] % voices.size]
        @next[name] += 1
        voice.stop
        voice.pitch = pitch
        voice.play
      rescue StandardError => e
        warn "Dot Popper: could not play #{name}: #{e.message}"
      end

      private

      def build(patches)
        patches.to_h do |name, patch|
          source = ::Lota::Audio::Source.new(sound_data(Presentation::Synth.render(patch)), :static)
          source.volume = @volume
          [name, [source] + Array.new(VOICES - 1) { source.clone }]
        end
      rescue StandardError => e
        warn "Dot Popper: playing without sound (#{e.message})"
        {}
      end

      def sound_data(samples)
        sound = ::Lota::Sound::SoundData.new(samples.size, Presentation::Synth::RATE, 16, 1)
        samples.each_with_index { |value, i| sound.sample = [i, value] }
        sound
      end
    end
  end
end

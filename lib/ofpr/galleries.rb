module Ofpr
  # Runs of thumbnails the original split across several centred lines read as one
  # gallery, which wraps by the width it has. It runs after the card has taken the
  # screenshot written before it, so a card keeps its picture.
  module Galleries
    def self.merge(blocks)
      blocks.each_with_object([]) do |block, merged|
        next merged.last[:pictures] += block[:pictures] if pair?(merged.last, block)

        merged << block
      end
    end

    def self.pair?(last, block) = block[:type] == 'gallery' && last&.fetch(:type) == 'gallery'
  end
end

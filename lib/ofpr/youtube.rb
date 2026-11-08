module Ofpr
  module Youtube
    ID = %r{(?:youtube\.com/(?:watch\?(?:[^\s)\]]*?&)?v=|v/|embed/)|youtu\.be/)([\w-]{11})}i

    class << self
      def ids(markdown) = markdown.to_s.scan(ID).flatten.uniq

      # Runs again over its own output without change: the videos it put in come out
      # first.
      def embed(blocks)
        seen = []
        blocks.reject { |block| block['type'] == 'video' }.flat_map do |block|
          next [block] unless block['type'] == 'prose'

          fresh = ids(block['markdown']) - seen
          seen.concat(fresh)
          [block, *fresh.map { |id| {'type' => 'video', 'id' => id} }]
        end
      end
    end
  end
end

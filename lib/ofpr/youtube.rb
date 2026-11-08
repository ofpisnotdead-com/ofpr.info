module Ofpr
  module Youtube
    ID = %r{(?:youtube\.com/(?:watch\?(?:[^\s)\]]*?&)?v=|v/|embed/)|youtu\.be/)([\w-]{11})}i
    LINK = /\[(?:[^\[\]]|\[[^\]]*\])*\]\((?:<[^>]*>|[^)\s]*)\)|https?:\S+/
    # A line holding nothing but links to videos, give or take the emphasis round them
    # and the full stop after them.
    ALONE = /\A(?<open>[*_]*)(?<links>(?:\s*(?:#{LINK}))+)\s*(?<close>[*_]*)[.!]?\s*\z/

    class << self
      def ids(markdown) = markdown.to_s.scan(ID).flatten.uniq

      # The chunk with each line that is only a video taken out and the player put in
      # its place. Emphasis the line closed for the lines before it moves onto them.
      def split(chunk)
        pieces = []
        opened = ''
        chunk.lines(chomp: true).each do |line|
          videos = alone(line)
          unless videos
            pieces << "#{opened}#{line}"
            opened = ''
            next
          end

          opened, closed = unmatched(videos[:open], videos[:close])
          pieces[-1] = pieces[-1].rstrip + closed if pieces.last.is_a?(String) && !closed.empty?
          pieces.concat(ids(line).each_with_index.map { |id, at| video(id, at.zero? ? line : nil) })
        end
        joined(pieces)
      end

      # A video named in a sentence keeps its sentence and gets its player after it.
      def after_sentences(blocks)
        seen = blocks.filter_map { |block| block[:id] if block[:type] == 'video' }
        blocks.flat_map do |block|
          next [block] unless block[:type] == 'prose'

          fresh = ids(block[:markdown]) - seen
          seen.concat(fresh)
          [block, *fresh.map { |id| video(id) }]
        end
      end

      def video(id, markdown = nil) = {type: 'video', id: id, markdown: markdown}

      private

      def alone(line)
        found = ALONE.match(line)
        found if found && found[:links].scan(LINK).all? { |link| link.match?(ID) }
      end

      # `**[a](x)**` opens and closes its own bold; `[a](x)**` closes one opened above.
      def unmatched(open, close)
        shared = open.size.downto(0).find { |n| open[(open.size - n)..] == close[0, n].reverse }
        [open[0, open.size - shared], close[shared..]]
      end

      def joined(pieces)
        pieces.chunk_while { |one, other| one.is_a?(String) && other.is_a?(String) }.flat_map do |run|
          next run unless run.first.is_a?(String)

          text = run.join("\n").strip
          text.empty? ? [] : [text]
        end
      end
    end
  end
end

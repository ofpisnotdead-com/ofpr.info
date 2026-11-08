module Ofpr
  module Paragraph
    NEEDS = /\b(?:need|requir)/i

    class << self
      # A download written on a line of its own inside a paragraph, split from the text
      # round it only by line breaks, is a download and not prose. What an addon needs
      # is not its download, so a paragraph naming that stays whole.
      def apart(chunk)
        lines = chunk.lines(chomp: true)
        @textless = bare?(chunk)
        return [chunk] unless splits?(chunk, lines)

        lines.chunk_while { |one, other| downloads_only?(one) == downloads_only?(other) }
          .map { |run| run.join("\n").strip }.reject(&:empty?)
      end

      private

      def splits?(chunk, lines)
        !chunk.match?(NEEDS) && lines.size > 1 && lines.any? { |line| downloads_only?(line) }
      end

      # A line whose bold runs on into the next stays with it, unless all there is in the
      # paragraph is links and pictures, which the bold round them does not change.
      def downloads_only?(line)
        return false if line.scan('**').size.odd? && !@textless

        bare?(line) && downloads(line).any? && downloads(line).size == line.scan(Blocks::ELEMENT).size
      end

      def bare?(text) = text.gsub(Blocks::ELEMENT, '').gsub(Blocks::EMPHASIS_MARKS, '').strip.empty?

      def downloads(text)
        text.scan(Blocks::ELEMENT).select do |_, label, url|
          url.delete_prefix('<').start_with?(Links::SECURE) && label.scan(Blocks::ELEMENT).size <= 1
        end
      end
    end
  end
end

require_relative 'need_items'

module Ofpr
  module Needs
    LEAD = /(?:to run this \w+,?|for the [^:]{1,60}?,|objects|the \w+ will|edit:)[\s*_]+/i
    WORD = /(?:needed|required)\s+addons|addons\s+(?:needed|required)|need's|needed|needs|you\s+need|
            requires|require|requirements|required/ix
    EXTRA = /optional(?:\s+addons)?|recommend(?:ed|ations?)(?:\s+addons)?/i
    QUALIFIED = /(?:[\s*_]+(?:only|for|to|in|by)\b[a-z\s*_]{0,24}?)?/
    MARKER = /\A[\s*_\[]*(?:#{LEAD})?(?:#{WORD}|#{EXTRA})#{QUALIFIED}[\s*_]*:[\s*_]*/i
    DECORATION = %r{\A(?:\s*!\[[^\]]*\]\(/ofpgm/images/[^)]*\)\s*)+\z}
    CONTINUES = /\A[\s*_]*[+,&]/
    STOPS = /\A[\s*_]*(?:source|thanks|credits?|change\s?log|note|features?|readme|install|known|enjoy|have\sfun|
            edit|links?\sfixed)\b/ix
    SENTENCE = /[a-z]{3,}\.\s+[A-Z][a-z]+\s+[a-z]/
    LINK = NeedItems::LINK
    NOISE = NeedItems::NOISE

    class << self
      # Each list of what a download needs, taken out of the chunks as one block: a
      # "Needed:" paragraph, then the packs either on that line joined with "+", or one
      # to a line or paragraph after it.
      def group(chunks)
        chunks = chunks.flat_map { |chunk| from_marker(chunk) }
        out = []
        at = 0
        while at < chunks.size
          block, rest, after = segment(chunks, at)
          out.push(*[block || chunks[at], rest].compact)
          at = block ? after : at + 1
        end
        out
      end

      private

      # A marker on a later line of a paragraph starts a paragraph of its own.
      def from_marker(chunk)
        lines = chunk.lines(chomp: true)
        at = lines.index { |line| line.match?(MARKER) }
        return [chunk] if at.nil? || at.zero?

        [lines[...at].join("\n").strip, lines[at..].join("\n")]
      end

      def segment(chunks, at)
        lines = chunks[at].lines(chomp: true)
        return unless lines.first.match?(MARKER)

        in_link = lines.first.match?(NeedItems::IN_LINK)
        own, inline = own_lines(lines)
        rest = lines.drop(own).join("\n").strip
        after = chunks_after(chunks, at + 1, inline && !in_link, rest.empty?)
        markdown = [lines.take(own).join("\n"), *chunks[(at + 1)...after]].join("\n\n")
        block = block(markdown, in_link)
        [block, (rest unless rest.empty?), after] if block
      end

      def block(markdown, in_link)
        found = NeedItems.of(in_link ? markdown : markdown.sub(MARKER, ''))
        {type: 'needs', title: title(markdown), items: found, markdown: markdown} unless found.empty?
      end

      def title(markdown)
        word = markdown[MARKER].to_s
        return 'Needed' unless word.match?(EXTRA)

        word.match?(/recommend/i) ? 'Recommended' : 'Optional'
      end

      # How many lines of its paragraph the list holds: an inline list runs on through
      # lines that open with "+", one written a pack to a line through pack lines.
      def own_lines(lines)
        head = lines.first.sub(MARKER, '')
        inline = !head.gsub(NOISE, '').empty?
        @style = download_style?(head)
        [1 + lines.drop(1).take_while { |line| inline ? line.match?(CONTINUES) : listed?(line) }.size, inline]
      end

      # Paragraphs after it join the list the same way, an inline one only through those
      # that open with "+".
      def chunks_after(chunks, from, inline, open)
        to = from
        while open && to < chunks.size
          lines = chunks[to].lines(chomp: true)
          break unless inline ? lines.first.match?(CONTINUES) : lines.all? { |line| listed?(line) }

          to += 1
        end
        to
      end

      # The article's own download often follows the list, written as "DOWNLOAD - ...".
      # A list that did not open in that style ends where that style starts.
      def listed?(line)
        return false unless item_line?(line)

        style = download_style?(line)
        return true if style.nil?

        @style = style if @style.nil?
        @style || !style
      end

      def furniture?(text) = text.gsub(NOISE, '').empty? || text.match?(DECORATION)

      def download_style?(text) = text[LINK, 1]&.match?(/\A[\s*_]*download/i)

      def item_line?(line)
        text = line.strip
        return true if furniture?(text)
        return false if text.match?(MARKER) || text.match?(STOPS) || text.start_with?('#', '![', '[![', '|')

        plain = NeedItems.clean(text.gsub(LINK, ' ').sub(NeedItems::NUMBERED, ''))
        plain.size <= 70 && !text.gsub(LINK, ' ').strip.match?(/[a-z]{2}[.!?]\z/i) && !plain.match?(SENTENCE)
      end
    end
  end
end

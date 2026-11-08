module Ofpr
  module Paragraph
    NEEDS = /\b(?:need|requir)/i

    class << self
      # A label and the download under it, written as one paragraph with a line break
      # between them, are the label's prose and a download. What an addon needs is not
      # its download, so a paragraph naming that, or holding a download above, stays whole.
      def apart(chunk)
        lines = chunk.lines(chomp: true)
        last_text = lines.rindex { |line| !downloads_only?(line) }
        return [chunk] if last_text.nil? || last_text == lines.size - 1

        text = lines[..last_text].join("\n")
        return [chunk] if text.match?(NEEDS) || downloads(text).any?

        [text.strip, lines[(last_text + 1)..].join("\n").strip]
      end

      private

      def downloads_only?(line)
        line.gsub(Blocks::ELEMENT, '').strip.empty? && downloads(line).any? &&
          downloads(line).size == line.scan(Blocks::ELEMENT).size
      end

      def downloads(text)
        text.scan(Blocks::ELEMENT).select do |_, label, url|
          url.delete_prefix('<').start_with?(Links::SECURE) && label.scan(Blocks::ELEMENT).size <= 1
        end
      end
    end
  end
end

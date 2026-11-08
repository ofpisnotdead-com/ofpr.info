require 'uri'
require_relative 'links'
require_relative 'youtube'

module Ofpr
  # The markdown is the prose. These are the three things in it that are not prose, and
  # a template that is handed them can lay them out instead of printing a 2003 table:
  # the addon card, the runs of thumbnails, and the downloads.
  #
  # Of 2,632 addon tables, 2,630 have exactly one screenshot in the paragraph before and
  # 2,626 exactly one download in the paragraph after. They are one card written as three
  # paragraphs, because html with no structure comes out that way.
  module Blocks
    # One markdown link or image, allowing the single level of nesting these bodies use:
    # a link whose text is a picture, and a label carrying a bracketed size.
    ELEMENT = /(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\((<[^>]*>|[^)]*)\)/
    TABLE = /\A\|.*\n\| --- /
    # A blank line, which after a `<br><br>` is a line holding the two spaces that
    # spell a line break in markdown.
    BLANK = /[ \t]*\n(?:[ \t]*\n)+[ \t]*/
    # The site's own layout graphics: separators, download buttons, language flags.
    DECORATION = %r{\A/ofpgm/images/}
    SIZE = /\[\s*([\d.,]+\s*[kKmMgG]?B)\s*\]/
    MIRROR = /(?:ftp|mirror)\s*#?\s*(\d)/i
    WRAPPED = /\A\[([^\[\]]*)\]\z/
    BOLD = '**'.freeze

    class << self
      def of(markdown)
        chunks = markdown.to_s.split(BLANK).map(&:strip).reject(&:empty?)
        pieces = chunks.flat_map { |chunk| chunk.match?(TABLE) ? [chunk] : Youtube.split(chunk) }
        Youtube.after_sentences(join(pieces.map { |piece| piece.is_a?(Hash) ? piece : block(piece) }))
      end

      private

      def block(chunk)
        return card(chunk) if chunk.match?(TABLE)
        return prose(chunk) unless chunk.gsub(ELEMENT, '').strip.empty?

        parts = elements(chunk)
        return download(parts) if parts.all? { |part| download?(part) }
        return gallery(parts) if parts.all? { |part| picture?(part) }

        prose(chunk)
      end

      # The card takes in the screenshot written before it and the download written
      # after it. Nothing else is moved: a paragraph that is not next to a card stays
      # the gallery or the download it is.
      def join(blocks)
        blocks.each_with_object([]) do |block, joined|
          last = joined.last
          next last[:downloads] = block[:links] if card_download?(last, block)

          block[:picture] = joined.pop[:pictures].first if card_picture?(last, block)
          joined << block
        end
      end

      def card_picture?(last, block)
        block[:type] == 'card' && last&.fetch(:type) == 'gallery' && last[:pictures].size == 1
      end

      def card_download?(last, block)
        block[:type] == 'download' && last&.fetch(:type) == 'card' && last[:downloads].empty?
      end

      def prose(chunk) = {type: 'prose', markdown: chunk}

      def gallery(parts) = {type: 'gallery', pictures: parts.map { |part| picture(part) }}

      def download(parts) = {type: 'download', links: parts.map { |part| link(part) }}

      # Almost every card has a single row, so the labels are kept beside the rows
      # rather than repeated into each one.
      def card(chunk)
        rows = chunk.lines.map(&:strip).reject(&:empty?).map { |line| cells(line) }
        labels = labels_of(rows.first)
        values = labels.empty? ? [rows.first] + rows.drop(2) : rows.drop(2)
        {type: 'card', picture: nil, downloads: [], labels: labels,
         rows: values.map { |row| plainly(row) }}
      end

      # The head row holds the labels, unless it is emphasised, which is how the sixty
      # tables that put a value there are written.
      def labels_of(head) = head.any? { |cell| cell.include?(BOLD) } ? [] : plainly(head)

      def plainly(row) = row.map { |cell| plain(cell) }

      def cells(line)
        line.delete_prefix('|').delete_suffix('|').split(' | ')
          .map { |cell| cell.gsub('\\|', '|').strip }
      end

      def elements(chunk)
        chunk.scan(ELEMENT).map do |bang, text, url|
          {image: bang == '!', text: text, url: bare(url)}
        end
      end

      # A thumbnail wears nothing but the picture. A link carrying a picture and a line
      # of text beside it is a sentence, and stays prose rather than lose the text.
      def picture?(part)
        return true if part[:image]

        inner = part[:text].match(ELEMENT)
        inner && inner[0] == part[:text].strip && inner[1] == '!'
      end

      def download?(part) = ours?(part[:url]) && part[:text].scan(ELEMENT).size <= 1

      def ours?(url) = url.start_with?(Links::SECURE)

      def bare(url) = url.delete_prefix('<').delete_suffix('>')

      # A bare picture stands on its own; a linked one is a thumbnail of the full size.
      def picture(part)
        return shot(part[:url], nil, part[:text]) if part[:image]

        inner = part[:text].match(ELEMENT)
        shot(bare(inner[3]), part[:url], inner[2])
      end

      def shot(thumb, full, alt)
        {thumb: thumb, full: full, alt: alt.to_s.strip,
         decoration: thumb.match?(DECORATION)}
      end

      def link(part)
        label = label_of(part[:text])
        picture = part[:text].match(ELEMENT)
        {url: part[:url], label: label, file: file_of(part[:url]),
         size: label[SIZE, 1]&.strip, mirror: part[:text][MIRROR, 1]&.to_i,
         button: picture && bare(picture[3])}
      end

      # A download whose whole label was a picture of a button has no label at all; the
      # mirror number is in the name of that picture, which is kept as `button` because
      # a few of them are a screenshot rather than a button.
      def label_of(text) = text.gsub(ELEMENT, ' ').gsub(BOLD, '').squeeze(' ').strip

      def file_of(url)
        URI::DEFAULT_PARSER.unescape(File.basename(url.split('?').first.to_s))
      end

      # A field holds a value, not markup: the template lays the card out now.
      def plain(text)
        bare = text.gsub(BOLD, '').strip
        bare.match(WRAPPED)&.[](1)&.strip || bare
      end
    end
  end
end

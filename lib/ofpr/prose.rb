require 'kramdown'

module Ofpr
  # A prose block is markdown. This is the only place it becomes html, so what the site
  # renders and what `rake port:verify` asserts about the port are the same thing.
  module Prose
    # One level of nesting, which these labels use: `[OFrP Pack [12.51 MB]](url)`.
    LABEL = /(?:[^\[\]]|\[[^\]]*\])*/
    TARGET = /\((?:<[^>]*>|[^)]*)\)/
    PICTURE = /!\[#{LABEL.source}\]#{TARGET.source}/
    LINK = /\[(#{LABEL.source})\]#{TARGET.source}/
    MARKS = /[*\\`]/

    def self.to_html(markdown) = Kramdown::Document.new(markdown.to_s).to_html

    # The id a heading with this text will be given when it is rendered, which is
    # what a link to that heading has to say. Asked rather than reimplemented, so
    # the link and the heading cannot drift apart.
    def self.heading_id(text)
      to_html("# #{text.to_s.gsub(/\s+/, ' ').strip}")[/id="([^"]*)"/, 1]
    end

    # The opening of a body as a line of plain text, for a listing: the pictures go, a
    # link keeps its words, and the marks come off.
    def self.plain(markdown, limit: nil)
      text = markdown.to_s.gsub(PICTURE, '').gsub(LINK, '\1').gsub(MARKS, '')
        .gsub(/\s+/, ' ').strip
      return text unless limit && text.length > limit

      "#{text[0, limit].sub(/\s\S*\z/, '')}..."
    end

    # The window of a text around the first search word, cut at whole words. The
    # excerpt `Snippet` makes is com_search's own and belongs to the facsimile; it
    # strips the tags without putting anything in their place, which welds an addon
    # card into `AuthorSizeTheSun`.
    def self.excerpt(text, terms, limit: 220)
      at = terms.filter_map { |term| text.index(/#{Regexp.escape(term)}/i) }.min
      return plain(text, limit: limit) if at.nil?

      from = [at - (limit / 3), 0].max
      piece = text[from, limit].to_s
      piece = piece.sub(/\A\S*\s/, '') if from.positive?
      piece = piece.sub(/\s\S*\z/, '') if from + limit < text.length
      "#{'... ' if from.positive?}#{piece.strip}#{' ...' if from + limit < text.length}"
    end
  end
end

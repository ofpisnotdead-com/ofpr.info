require 'cgi'
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

    # Some captured text was encoded twice before we ever saw it: the menu page's
    # description holds `mod&amp;#39;s`, which prints as an entity rather than as an
    # apostrophe. Decode until it settles.
    def self.decoded(text)
      text = text.to_s
      3.times do
        once = CGI.unescapeHTML(text)
        return text if once == text

        text = once
      end
      text
    end

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

    # The window of a text around the first search word, cut at whole words. It reads
    # the port rather than the stored html, which has no spaces between an addon
    # card's cells and so welds one into `AuthorSizeTheSun`.
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

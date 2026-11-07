require 'cgi'

module Ofpr
  # The excerpt com_search shows under a result. Joomla walks the plain text in chunks of
  # about 200 characters, each extended to the next space, and prints the first chunk
  # that holds the search word; the leading ellipsis appears only when that is not the
  # first chunk. Reproduced from SearchHelper::_smartSubstr.
  class Snippet
    CHUNK = 200

    # prepareSearchContent, which is what com_search chunks: script blocks and curly
    # tags go, a line breaking or block closing tag becomes one space, strip_tags takes
    # the rest without leaving a space behind, and nothing normalises the whitespace -
    # the newlines of the stored markup are counted into the chunk like any character.
    BREAKS = %r{<(?:br[^/>]*?/|hr[^/>]*?/|/(?:div|h[1-6]|li|p|td))>}i

    # CGI.unescapeHTML leaves a named entity alone, and the stored markup carries 4,777
    # of them. A non-breaking space counted as six characters rather than one moves the
    # chunk boundary and drops the last word of an excerpt, so they are decoded here.
    NAMED = {'&nbsp;' => "\u00a0", '&uuml;' => "\u00fc", '&auml;' => "\u00e4",
             '&oacute;' => "\u00f3", '&trade;' => "\u2122"}.freeze

    # Joomla cloaked an email address as the page was rendered, so the capture carries
    # this notice where the stored article held the address. com_search chunked the
    # stored text, so the words the notice replaced go back in before the chunking.
    CLOAKED = 'This email address is being protected from spambots. You need JavaScript enabled to view it.'.freeze

    LEAD = '...&#160;'.freeze
    TAIL = '&#160;...'.freeze

    def initialize(body_html, terms, cloak_text: nil)
      @cloak_text = cloak_text.to_s
      @text = plain(body_html)
      @terms = terms.reject(&:empty?)
    end

    def to_html
      return '' if @text.empty?

      position, chunk = matching_chunk
      return opening unless chunk

      # The captures carry no trailing ellipsis once the chunk has reached the end.
      lead = position.positive? ? LEAD : ''
      tail = position + chunk.length < @text.length ? TAIL : ''
      "#{lead}#{highlight(chunk)}#{tail}"
    end

    private

    # Script blocks go whole before the tags are stripped, so the cloaking script's
    # javascript is not chunked. Stripping a tag leaves no space behind, which is why a
    # table cell boundary joins the words either side of it the way the site showed them.
    def plain(html)
      text = html.to_s.gsub(%r{<script\b.*?</script>}mi, '').gsub(%r{<style\b.*?</style>}mi, '')
      text = text.gsub(/\{.+?\}/, '').gsub(BREAKS, ' ')
      decode(text.gsub(/<[^>]*>/, '')).gsub(CLOAKED, @cloak_text)
    end

    def decode(text) = CGI.unescapeHTML(text).gsub(/&[a-zA-Z]+;/) { |e| NAMED.fetch(e, e) }

    # The chunk holding a term, or nil when no chunk does.
    def matching_chunk
      position = 0
      while position < @text.length
        chunk = chunk_at(position)
        return [position, chunk] if @terms.any? { |term| chunk.downcase.include?(term.downcase) }

        position += chunk.length + 1
      end
      nil
    end

    # What _smartSubstr prints when the word is nowhere: the opening of the text, and no
    # ellipsis at all when there is no space past the first chunk to break on.
    def opening
      space = @text.index(' ', CHUNK)
      space ? "#{highlight(@text[0...space])}#{TAIL}" : highlight(@text[0, CHUNK])
    end

    # Up to the first space at or after 200 characters, or the rest of the text.
    def chunk_at(position)
      space = @text.index(' ', position + CHUNK)
      space ? @text[position...space] : @text[position..]
    end

    def highlight(text)
      @terms.reduce(text) do |marked, term|
        marked.gsub(/#{Regexp.escape(term)}/i) { %(<span class="highlight">#{Regexp.last_match(0)}</span>) }
      end
    end
  end
end

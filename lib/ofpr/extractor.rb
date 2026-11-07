require 'cgi'
require 'json'
require 'time'

module Ofpr
  # Turns one captured page into a row. The capture mirrors the url space, so a page's
  # path below the root is its url, its id and its section.
  class Extractor
    TITLE_PREFIX = /\AOFP\.info\s*2\.5\s*-\s*/
    LD_BLOCK = %r{<script type="application/ld\+json">(.*?)</script>}m
    # A menu page has no itemLinks block, so the body there runs to the end of the item.
    BODY = %r{<div class="itemFullText">(.*?)(?:<div class="itemLinks|</article>)}m
    PAGE_TITLE = %r{<title>(.*?)</title>}m
    # A backslash that starts no legal JSON escape. Joomla emits article titles into
    # ld+json unescaped, so a title like `ORCS T80UM\T90` makes the block unparsable.
    BAD_ESCAPE = %r{\\(?![\\/"bfnrtu])}
    HITS = /Read\s+([\d,.\s]+)\s+times/
    SECTION_LABEL = %r{<span>Published in</span>\s*<a[^>]*>([^<]+)</a>}
    AUTHOR_LINK = /Written by&nbsp;<a[^>]*href="([^"]+)"/
    META_DESCRIPTION = /<meta name="description" content="([^"]*)"/
    CLOAK_TEXT = /addy_text[0-9a-f]*\s*=\s*'([^']*)'/

    Row = Struct.new(:id, :slug, :url_path, :section, :section_label, :title, :description,
      :author, :author_url, :published_at, :modified_at, :hits, :body_html, :cloak_text,
      keyword_init: true)

    PageRow = Struct.new(:url_path, :title, :description, :author, :author_url,
      :published_at, :modified_at, :body_html, keyword_init: true)

    class Invalid < StandardError; end

    def self.call(...) = new(...).call

    def self.menu_page(...) = new(...).menu_page

    def initialize(path, root: nil)
      @path = path
      @raw = File.binread(path)
      @root = File.expand_path(root || File.dirname(path))
    end

    def call
      raise Invalid, 'page is empty' if @raw.strip.empty?

      article = article_block or raise Invalid, 'no ld+json Article block'
      row(article, body)
    end

    def menu_page
      article = article_block or raise Invalid, 'no ld+json Article block'

      PageRow.new(url_path: url_path, title: menu_title, description: description(article),
        author: author(article), author_url: author_url,
        published_at: time(article['datePublished']),
        modified_at: time(article['dateModified']), body_html: body)
    end

    private

    # A menu page shows no headline, so the browser title is the only name it has.
    def menu_title = html[PAGE_TITLE, 1].to_s.sub(TITLE_PREFIX, '').strip

    def row(article, body_html)
      Row.new(id: id, slug: slug, url_path: url_path, section: section,
        section_label: html[SECTION_LABEL, 1]&.strip, title: title(article),
        description: description(article), author: author(article),
        author_url: author_url,
        published_at: time(article['datePublished']),
        modified_at: time(article['dateModified']), hits: hits, body_html: body_html,
        cloak_text: cloak_text)
    end

    def body
      found = html[BODY, 1]
      raise Invalid, 'no article body' if found.nil? || found.strip.empty?

      balance(found.strip)
    end

    # The capture between itemFullText and itemLinks carries the closers of the
    # containers either side of the body, so the text over-closes its own divs.
    def balance(found)
      found = found.sub(%r{\s*</div>\s*\z}, '') while closers(found) > openers(found)
      found
    end

    # The ld+json description is sometimes Cloudflare's email-protection notice, picked
    # up from an obfuscated address at the top of the body; the meta tag holds the real
    # text, and it is what the site's own search looked at.
    def description(article) = html[META_DESCRIPTION, 1] || article['description']

    # The visible text of a cloaked mailto link, which the body no longer holds.
    def cloak_text
      texts = html.scan(CLOAK_TEXT).flatten.map { |value| CGI.unescapeHTML(value) }
      texts.empty? ? nil : texts.uniq.join(' ')
    end

    # Only an author with an account is linked, and the capture holds no author pages.
    def author_url = html[AUTHOR_LINK, 1]&.delete_suffix('.html')

    def hits = html[HITS, 1]&.gsub(/\D/, '')&.to_i

    def openers(found) = found.scan(/<div\b/i).length

    def closers(found) = found.scan(%r{</div>}i).length

    def html = @html ||= @raw.force_encoding('UTF-8').scrub

    def basename = @basename ||= File.basename(@path, '.html')

    def id = Integer(basename.split('-', 2).first)

    def slug = basename.split('-', 2).last

    def relative = @relative ||= File.expand_path(@path).delete_prefix("#{@root}/")

    def url_path = "/#{relative.delete_suffix('.html')}"

    def section = File.dirname(relative) == '.' ? '' : File.dirname(relative)

    def article_block
      html.scan(LD_BLOCK).each do |(block)|
        parsed = parse_json(block)
        return parsed if parsed && parsed['@type'] == 'Article'
      end
      nil
    end

    def parse_json(block)
      JSON.parse(block)
    rescue JSON::ParserError
      begin
        JSON.parse(block.gsub(BAD_ESCAPE) { '\\\\' })
      rescue JSON::ParserError
        nil
      end
    end

    def title(article)
      article['headline'].to_s.sub(TITLE_PREFIX, '').strip
    end

    def author(article)
      value = article['author']
      value.is_a?(Hash) ? value['name'] : value
    end

    # The capture writes these with a +00:00 offset, so they are read as UTC rather
    # than as wall-clock time wherever the importer happens to run.
    def time(value)
      Time.parse("#{value} UTC")
    rescue ArgumentError
      nil
    end
  end
end

module Ofpr
  # The tag, class and id skeleton of a page, which is what "the same layout" means:
  # text and attribute values belong to the content, the shape does not.
  module Skeleton
    # Stored article markup is content. It nests divs of its own, so the region has to
    # be found by balancing rather than by stopping at the first close.
    CONTENT = [['<div class="itemIntroText">', '<div', '</div>'],
               ['<div class="itemFullText">', '<div', '</div>'],
               ['<dd class="result-text">', '<dd', '</dd>']].freeze

    PAGER_START = '<nav class="pagination">'.freeze
    PAGER = %r{#{PAGER_START}.*?</nav>}m
    # The mirror this site was recovered from lost the numbered links of every pager
    # past page six, and test.ofpr.info serves the same loss, so those items have no
    # reference to compare against. The items around them still do.
    NUMBER_ITEM = %r{<li>\s*(?:<a[^>]*>.*?</a>|<span[^>]*>.*?</span>)?\s*</li>}m
    FRAME_ITEM = %r{<li class="(pagination-(?:start|prev|next|end)|counter)">(.*?)</li>}m

    # The cookie notice is off unless CONSENT=1, so its markup comes out of the capture
    # too when the app being compared does not have it on.
    CONSENT_LINK = /<link[^>]*fmalertcookies[^>]*>/
    CONSENT_SCRIPT = %r{<script type="text/javascript">var d = new Date\(\);var acceptCookie.*?</script>}m

    def self.without_consent(html) = html.gsub(CONSENT_LINK, '').gsub(CONSENT_SCRIPT, '')

    LIST_START = ['<div class="itemList">', '<dl class="search-results">'].freeze
    ITEM_SPLIT = /class="itemContainer|<dt class="result-title">/
    ITEM_ID = /href="[^"]*?(\d{3,5})-[a-z0-9-]+(?:\.html)?"/

    def self.of_without_numbers(html) = of(html.gsub(PAGER) { |pager| pager.gsub(NUMBER_ITEM, '') })

    def self.degraded_pager?(html) = html.match?(PAGER) && html[PAGER].include?('<li></li>')

    # Start, Prev, Next, End and the counter survived the loss.
    def self.pager_frame(html)
      html.scan(PAGER).flat_map do |pager|
        pager.scan(FRAME_ITEM).map do |name, inner|
          next "counter:#{inner.strip}" if name == 'counter'

          href = inner[/href="([^"]*)"/, 1]
          "#{name}:#{href ? pager_target(href) : 'disabled'}"
        end
      end
    end

    # The capture holds the mirror's rewritten filename and the app holds the live url,
    # so a pager target compares as the page and offset it points at. One captured page
    # has its pager written out with the host on the front.
    def self.pager_target(href)
      path, _, query = href.sub(%r{\Ahttps?://[^/]+}, '').delete_prefix('/')
        .partition(/%3F|\?/)
      path = path.delete_suffix('.html')
      path = '' if path == 'index'
      "/#{path}?start=#{query[/start=(\d+)/, 1] || '0'}"
    end

    # What a listing lists, which the skeleton cannot show: the ids live in hrefs, so a
    # page listing the wrong articles in the wrong order still has the right shape.
    def self.listed_ids(html)
      at = LIST_START.filter_map { |marker| html.index(marker) }.min
      return [] unless at

      region = html[at...(html.index(PAGER_START, at) || html.length)]
      region.split(ITEM_SPLIT)[1..].to_a.filter_map { |item| item[ITEM_ID, 1] }
    end

    def self.of(html)
      html = html.gsub(/<!--.*?-->/m, '').gsub(%r{<(script|style)\b.*?</\1>}mi, '<\1/>')
      CONTENT.each { |opener, open_tag, close_tag| html = blank(html, opener, open_tag, close_tag) }
      html.scan(%r{<(/?)([a-zA-Z0-9]+)([^>]*)>}).map do |close, tag, attrs|
        "<#{close}#{tag.downcase}#{keys(attrs)}>"
      end
    end

    def self.blank(html, opener, open_tag, close_tag)
      while (at = html.index(opener))
        inner = at + opener.length
        html = html[0...at] + opener.sub('<', '<!') + close_tag +
               html[closing(html, inner, open_tag, close_tag)..]
      end
      html.gsub("<!#{opener[1..]}", opener)
    end

    def self.closing(html, from, open_tag, close_tag)
      depth = 1
      html.to_enum(:scan, /#{Regexp.escape(open_tag)}\b|#{Regexp.escape(close_tag)}/).each do
        at = Regexp.last_match.begin(0)
        next if at < from

        depth += Regexp.last_match[0] == close_tag ? -1 : 1
        return at + close_tag.length if depth.zero?
      end
      html.length
    end

    def self.keys(attrs)
      %w[class id].filter_map do |name|
        value = attrs[/\b#{name}="([^"]*)"/, 1]
        " #{name}=#{value.split.sort.join(' ')}" if value
      end.join
    end
  end
end

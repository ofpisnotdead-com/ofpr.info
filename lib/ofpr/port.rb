require_relative 'blocks'
require_relative 'markdown'
require_relative 'prose'

module Ofpr
  # The port has to be provable rather than plausible, because a download link dropped
  # in article 7,413 looks exactly like a short article. So the markdown is rendered
  # back to html and the two pages are compared: same links, same words, same pictures.
  # Asserting it this way also proves the markdown parses as the markdown it meant to be,
  # which is where a url holding a bracket or a space goes wrong.
  module Port
    NOT_WORD = /[^\p{Alnum}]+/
    # Shapes a markdown reader makes out of a character somebody typed. A list and a rule
    # are not among them: hundreds of these bodies draw those on purpose and mean them.
    INVENTED = %w[blockquote h1 h2 h3 h4 h5 h6 table].freeze

    class << self
      # The complaints about one body, empty when the port kept everything. The blocks
      # are held to the same standard by writing them back out as markdown. Given what
      # the import stored, it also says when that is no longer what these rules write,
      # which is the signal to import again.
      def check(html, stored: nil, stored_blocks: nil)
        before = Markdown.dom(html)
        markdown = Markdown.of(html)
        after = Markdown.dom(render(markdown))
        blocks = Blocks.of(markdown)
        [*kept(before, after, 'the markdown'),
         *invented(before, after),
         *kept(after, Markdown.dom(render(unblock(blocks))), 'the blocks'),
         unstable(html, markdown),
         stale(stored, markdown, 'markdown'),
         stale(stored_blocks, json(blocks), 'blocks')].compact
      end

      def invented(before, after)
        INVENTED.filter_map do |tag|
          got = after.css(tag).size - before.css(tag).size
          "the markdown invented #{got} <#{tag}>" if got.positive?
        end
      end

      # Same links, same words, same pictures, going in and coming out again.
      def kept(before, after, what)
        [missing(urls(before), urls(after), "links in #{what}"),
         missing(words(before), words(after), "words in #{what}"),
         pictures(before, after, what)]
      end

      # The blocks written back out as the markdown they were read from. Nothing is
      # asserted about the shape they were given; what is asserted is that giving them
      # that shape dropped nothing. `file`, `size` and `mirror` are read back out of a
      # label and a url, so they are not written here and cannot be counted twice.
      def unblock(blocks) = blocks.filter_map { |block| source(block) }.join("\n\n")

      def json(blocks) = JSON.parse(JSON.generate(blocks))

      def render(markdown) = Prose.to_html(markdown)

      def urls(body)
        body.xpath('.//@href | .//@src')
          .map { |node| Markdown.address(node.value) }.reject(&:empty?).tally
      end

      # The text a browser would show, with a space wherever the markup held one run of
      # text apart from the next: the tables separate their cells with markup alone, so
      # reading a body as one string would weld `Author` to `Size`.
      def words(body) = shown(body, []).join.gsub(NOT_WORD, ' ').split.tally

      private

      def shown(node, out)
        node.children.each do |child|
          next out << child.text if child.text?
          next unless child.element?

          block = Markdown::BLOCK.include?(child.name.downcase)
          out << ' ' if block
          shown(child, out)
          out << ' ' if block
        end
        out
      end

      # Both sides counted, so a repeated link that lost one of its copies is caught and
      # the screenshot lifted out above its table is not.
      def missing(before, after, kind)
        lost = excess(before, after)
        gained = excess(after, before)
        return if lost.empty? && gained.empty?

        "lost #{kind} #{sample(lost)}#{" and invented #{sample(gained)}" unless gained.empty?}"
      end

      def excess(one, other)
        one.filter_map { |item, n| [item, n - other.fetch(item, 0)] if n > other.fetch(item, 0) }
      end

      def pictures(before, after, what)
        want = before.css('img').size
        got = after.css('img').size
        "#{want} pictures became #{got} in #{what}" unless want == got
      end

      def source(block)
        case block[:type]
        when 'prose', 'video' then block[:markdown]
        when 'gallery' then block[:pictures].map { |shot| shot_source(shot) }.join(' ')
        when 'download' then block[:links].map { |link| link_source(link) }.join(' ')
        when 'card' then card_source(block)
        end
      end

      def card_source(block)
        [shot_source(block[:picture]), *block[:labels], *block[:rows].flatten,
         *block[:downloads].map { |link| link_source(link) }].compact.join("\n\n")
      end

      def shot_source(shot)
        return nil unless shot

        picture = "![#{shot[:alt]}](#{Markdown.target(shot[:thumb])})"
        shot[:full] ? "[#{picture}](#{Markdown.target(shot[:full])})" : picture
      end

      def link_source(link)
        button = "![](#{Markdown.target(link[:button])})" if link[:button]
        "[#{[button, link[:label]].compact.join(' ')}](#{Markdown.target(link[:url])})"
      end

      def unstable(html, markdown)
        'converts differently when run again' unless Markdown.of(html) == markdown
      end

      def stale(stored, fresh, what)
        "the stored #{what} is not what these rules write" if stored && stored != fresh
      end

      def sample(pairs)
        shown = pairs.first(3).map { |item, n| n > 1 ? "#{item.inspect} x#{n}" : item.inspect }
        (shown + (pairs.size > 3 ? ["and #{pairs.size - 3} more"] : [])).join(', ')
      end
    end
  end
end

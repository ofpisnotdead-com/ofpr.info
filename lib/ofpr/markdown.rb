require 'nokogiri'
require_relative 'prose'

module Ofpr
  # The stored article bodies are 1990s html: five tags carry 85% of them, `<center>` is
  # a sixth of all tags and means nothing once a template does the centring, and the
  # tables are written with unclosed cells. This turns one into markdown so a modern
  # template has something clean to render, while `body_html` stays the archival record.
  module Markdown
    # Stamped on every row the import writes, so a body converted by older rules can be
    # told from one converted by these. It covers the blocks read off the markdown too,
    # because the import writes the pair.
    VERSION = 'rules/2'.freeze

    # The site's own addresses. A link to one of these becomes a path, so the markdown
    # does not carry a host that has already moved once.
    SITE = %r{\Ahttps?://(?:www\.)?(?:ofpr\.info\.paradoxstudio\.uk|test\.ofpr\.info|ofpr\.info)(?=/|\z)}i
    UP = %r{\A(?:\.\./)+}
    # Italics are asterisks, not underscores: an underscore is part of a file name far
    # more often than it is emphasis here.
    EMPHASIS = {'b' => '**', 'strong' => '**', 'i' => '*', 'em' => '*'}.freeze
    BREAKS = %w[p div center blockquote dl dt dd pre].freeze
    HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze
    # Where the html itself holds one run of text apart from the next. Two text nodes
    # with only inline tags between them were one word on the page, which is what
    # `Port` needs to know to tell a lost space from a kept one.
    BLOCK = (BREAKS + HEADINGS + %w[table thead tbody tfoot tr td th ul ol li br hr]).freeze
    DROP = %w[script style].freeze
    # Markdown reads a bracket, a space or a quote in a url as the end of it.
    PLAIN_URL = /\A[^\s()<>"]*\z/
    # Characters no url may hold raw, and which a few of these hrefs hold anyway:
    # `href="/<br>http://..."` is in the archive exactly like that.
    INVALID = /[<>"]/
    ESCAPE = /([\\`*<])/
    NBSP = "\u00a0".freeze
    # A line break is two spaces at the end of a line and nothing else in markdown, and
    # `<br>` is the second commonest tag in these bodies. It is carried as a mark until
    # the end, because every other step here collapses runs of spaces.
    BREAK = "\u0001".freeze
    # Whitespace, counting a line break mark as some of it: `strip` knows nothing
    # about the mark and would leave one inside a pair of emphasis marks.
    PADDING = /\A[\s\u0001]+|[\s\u0001]+\z/
    # A run of whitespace inside a link or an emphasis comes to a single space, unless
    # a `<br>` was part of it: html collapses even a blank line, a `<br>` it does not.
    INLINE_SPACE = /[\s\u0001]*[\n\u0001][\s\u0001]*/
    FOLLOWING_HEADING = HEADINGS.map { |tag| "following::#{tag}" }.join('|').freeze
    CLOAKED = /getElementById\('cloak([0-9a-f]+)'\)/
    LITERAL = /'([^']*)'/
    # One javascript assignment. A quoted piece is taken whole, because the entities
    # the address is spelled with are full of the semicolon that ends the statement.
    ASSIGNED = /\s*=\s*((?:'[^']*'|[^;'])*)/

    class << self
      def of(html) = Writer.new(dom(html)).call

      # The body as a browser would hold it: the cloaking script run, the embeds and
      # form buttons reduced to the link and the picture they amount to, and the scripts
      # gone. The converter and its verification both read the body through this, so
      # they are looking at the same page.
      def dom(html)
        fragment = Nokogiri::HTML5.fragment(html.to_s)
        fragment.css('script').each { |script| uncloak(fragment, script) }
        name_anchors(fragment)
        fragment.css('embed', 'iframe').each { |node| as_link(node) }
        fragment.css('input').each { |node| as_picture(node) }
        fragment.css(*DROP).each(&:unlink)
        fragment
      end

      # A url the site serves is written as a path; anything else is left alone.
      def address(url)
        text = url.to_s.gsub(/[\r\n\t]/, '').strip.sub(SITE, '')
        text = "/#{text.sub(UP, '')}" if text.match?(UP)
        text.gsub(INVALID) { |char| format('%%%02X', char.ord) }
      end

      def target(url)
        address(url).then { |text| text.match?(PLAIN_URL) ? text : "<#{text}>" }
      end

      private

      # Joomla hid an author's address behind a script that assembles it from
      # entity-encoded pieces and writes the link into the span above. Running it is
      # what a browser does, and the span holds only a placeholder until it has.
      def uncloak(fragment, script)
        id = script.text[CLOAKED, 1]
        span = id && fragment.at_css("#cloak#{id}")
        address = literals(script.text, /\baddy#{id}#{ASSIGNED.source}/) if span
        return if address.nil? || address.empty?

        label = literals(script.text, /\baddy_text#{id}#{ASSIGNED.source}/)
        label = address if label.empty?
        span.children.unlink
        # Some of these spans already sit inside a mailto link of their own, and a link
        # cannot hold another: the label alone is what is left to show.
        span.add_child(span.ancestors('a').any? ? text(span, label) : anchor(span, "mailto:#{address}", label))
      end

      # The pieces of one javascript variable, in the order the script appends them.
      # The script hands them to `innerHTML`, so the browser decodes every entity in
      # them and not only the handful `CGI.unescapeHTML` knows.
      def literals(source, pattern)
        Nokogiri::HTML5.fragment(source.scan(pattern).join.scan(LITERAL).join).text
      end

      # The mods page is a dozen sections behind a numbered index, and the numbers run
      # in the order the mods were added rather than the order they sit in. The heading
      # each anchor stands in front of is the target now, under the name it will be
      # rendered with, so a link into the page says which mod it means.
      def name_anchors(fragment)
        fragment.css('a[name]:not([href])').each do |anchor|
          slug = slug_for(anchor)
          retarget(fragment, anchor['name'], slug) if slug

          anchor.children.any? ? anchor.replace(anchor.children) : anchor.unlink
        end
      end

      def slug_for(anchor)
        heading = anchor.at_xpath(FOLLOWING_HEADING)
        heading && Prose.heading_id(escaped(heading.text))
      end

      def retarget(fragment, name, slug)
        target = /##{Regexp.escape(name)}\z/
        fragment.css('a[href]').each do |link|
          link['href'] = link['href'].sub(target, "##{slug}") if link['href'].match?(target)
        end
      end

      # A flash or youtube embed has no text and no picture, and markdown cannot play
      # it: the url is the whole of the content, so it becomes a link showing itself.
      def as_link(node)
        src = node['src'].to_s.strip
        src.empty? ? node.unlink : node.replace(anchor(node, src, src))
      end

      # A form's submit button is a picture of a button. The rest of a form is machinery
      # that cannot work without a server and says nothing on its own.
      def as_picture(node)
        return unless node['type'].to_s.casecmp?('image') && node['src']

        picture = Nokogiri::XML::Node.new('img', node.document)
        picture['src'] = node['src']
        picture['alt'] = node['alt'] if node['alt']
        node.replace(picture)
      end

      def escaped(text) = text.gsub(ESCAPE, '\\\\\\1')

      def anchor(node, href, label)
        link = Nokogiri::XML::Node.new('a', node.document)
        link['href'] = href
        link.content = label
        link
      end

      def text(node, label) = Nokogiri::XML::Text.new(label, node.document)
    end

    # Walks the prepared body once, appending pieces of markdown.
    class Writer
      HANDLERS = {
        'a' => :link, 'img' => :image, 'br' => :newline, 'hr' => :rule, 'table' => :table,
        'li' => :item, 'ul' => :list, 'ol' => :list,
        'h1' => :heading, 'h2' => :heading, 'h3' => :heading,
        'h4' => :heading, 'h5' => :heading, 'h6' => :heading,
        'b' => :emphasis, 'strong' => :emphasis, 'i' => :emphasis, 'em' => :emphasis
      }.freeze

      def initialize(dom)
        @dom = dom
        @out = []
      end

      def call
        children(@dom)
        tidy(@out.join)
      end

      private

      def visit(node)
        return @out << escape(node.text) if node.text?
        return unless node.element?

        name = node.name.downcase
        send(HANDLERS.fetch(name, :other), node, name)
      end

      def other(node, name)
        return children(node) unless BREAKS.include?(name)

        @out << "\n"
        children(node)
        @out << "\n"
      end

      def children(node) = node.children.each { |child| visit(child) }

      def inner(node)
        held = @out
        @out = []
        text = begin
          children(node)
          @out.join
        end
        @out = held
        text
      end

      def link(node, _name)
        href = Markdown.target(node['href'])
        core, lead, tail = spaced(inner(node))
        @out << lead << (href.empty? ? core : "[#{core}](#{href})") << tail
      end

      def image(node, _name)
        src = Markdown.target(node['src'])
        @out << "![#{escape(node['alt'].to_s.strip)}](#{src})" unless src.empty?
      end

      def emphasis(node, name)
        mark = EMPHASIS.fetch(name)
        core, lead, tail = spaced(inner(node))
        @out << lead << (core.empty? ? '' : "#{mark}#{core}#{mark}") << tail
      end

      # A space just inside a tag belongs outside the marks that replace it: `**Mod **`
      # is not emphasis at all, and a space on the inside of a link is dropped when it
      # is rendered, welding the link to the word before it.
      def spaced(text)
        lead, core, tail = text.partition(text.gsub(PADDING, ''))
        [oneline(core), lead, tail]
      end

      # A blank line would end a link or an emphasis rather than sit inside one, and
      # these bodies have them in the middle of a sentence.
      def oneline(text)
        text.gsub(INLINE_SPACE) { |run| run.include?(BREAK) ? "#{BREAK}\n" : ' ' }
      end

      # A heading is one line of markdown with no blank line inside it, which rules out
      # the pictures and the tables that a couple of these headings wrap.
      def heading(node, name)
        text = oneline(inner(node).gsub(PADDING, ''))
        @out << "\n\n#{'#' * name[1].to_i} #{text}\n\n" unless text.empty?
      end

      def newline(_node, _name) = @out << BREAK << "\n"

      def rule(_node, _name) = @out << "\n\n---\n\n"

      def list(node, _name)
        @out << "\n"
        children(node)
        @out << "\n"
      end

      def item(node, _name)
        @out << "\n- "
        children(node)
      end

      # Nearly every table is the same addon card: a screenshot spanning the rows, two to
      # four labelled fields, and a download button spanning the columns. The cells that
      # hold only a picture are lifted out - they are the screenshot above and the buttons
      # below, not data - and what is left is a plain grid of labels and values.
      def table(node, _name)
        rows = node.xpath('./tr | ./thead/tr | ./tbody/tr | ./tfoot/tr').map { |row| cells(row) }
        return if rows.empty?

        lead, trail = pictures(rows)
        apart(lead)
        @out << "\n\n" << grid(rows.map { |row| row.reject(&:last).map(&:first) }) << "\n\n"
        apart(trail)
      end

      def apart(parts)
        @out << "\n\n" << parts.join("\n\n") << "\n\n" unless parts.empty?
      end

      # Each cell as its markdown and whether a picture is all it holds.
      def cells(row)
        row.xpath('./td | ./th').filter_map do |cell|
          text = inner(cell).gsub(PADDING, '')
          next if text.empty?

          [text, cell.text.strip.empty? && cell.at_xpath('.//img') ? true : false]
        end
      end

      def pictures(rows)
        first, *rest = rows
        [first.select(&:last).map(&:first),
         rest.flat_map { |row| row.select(&:last).map(&:first) }]
      end

      def grid(rows)
        rows = rows.reject(&:empty?)
        widths = rows.map(&:size).uniq
        return rows.map { |row| row.join(' - ') }.join("\n") unless table?(rows, widths)

        head, *body = rows.map { |row| "| #{row.map { |cell| flatten(cell) }.join(' | ')} |" }
        [head, "|#{' --- |' * widths.first}", *body].join("\n")
      end

      # A markdown table needs a rectangle of at least two columns to be one.
      def table?(rows, widths) = rows.size > 1 && widths.size == 1 && widths.first > 1

      # A row of a markdown table is one line, so a cell cannot hold a break at all.
      def flatten(cell)
        cell.gsub('|', '\\|').gsub(BREAK, ' ').gsub(/\s*\n\s*/, ' ')
      end

      def escape(text) = text.gsub(ESCAPE, '\\\\\1')

      # A run of spaces is collapsed everywhere except inside a url, where two of them
      # are two characters of a file name. A line that opens with a number and a dot is
      # a numbered list to a markdown reader, which eats the number, so it is escaped -
      # behind a bullet too, where it would otherwise open a list inside the list.
      def tidy(text)
        text
          .tr(NBSP, ' ')
          .gsub(/<[^<>\n]*>|[ \t]+/) { |run| run.start_with?('<') ? run : ' ' }
          .gsub(/ ?\n ?/, "\n")
          .gsub(/^-(?=\n|\z)/, '')
          .gsub(/\n{3,}/, "\n\n")
          .gsub(/^(- )?(\d+)([.)])(?=\s)/, '\1\2\\\\\3')
          .gsub(BREAK, '  ')
          .strip
      end
    end
  end
end

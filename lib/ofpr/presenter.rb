module Ofpr
  # What the templates ask for: the blocks of a body, the pieces of a card, and the
  # small formatting the archive's data needs before it can be printed.
  module Presenter
    def blocks(record) = record[:body_blocks] || []

    def prose(markdown) = Prose.to_html(markdown)

    # A picture lives under `/ofpgm`, which is the mirror in development and the file
    # server in production. Pointing straight at it saves the redirect the route would
    # otherwise answer with, once for every picture on the page.
    def asset(path)
      base = settings.cdn_base.to_s.delete_suffix('/')
      return path if base.empty? || !path.to_s.start_with?('/ofpgm/')

      "#{base}#{path.delete_prefix('/ofpgm')}"
    end

    # A field holds a line, not a paragraph, so the wrapper kramdown puts round it
    # comes off; a link inside it survives.
    def inline(markdown) = Prose.to_html(markdown).strip.sub(%r{\A<p>(.*)</p>\z}m, '\\1')

    # Most addon entries are a card and nothing else, so when there is no prose the
    # card's own row says what the listing would otherwise leave blank.
    def intro(article)
      opening = blocks(article).find { |block| block['type'] == 'prose' }
      return Prose.plain(opening['markdown'], limit: 190) if opening

      card = blocks(article).find { |block| block['type'] == 'card' }
      card && card['rows'].first&.join(' - ')
    end

    # The picture a listing shows: the card's screenshot, or the first thumbnail that
    # is not one of the site's own separators.
    def first_picture(article)
      blocks(article).each do |block|
        shot = block['type'] == 'card' ? block['picture'] : shown_pictures(block['pictures']).first
        return shot if shot
      end
      nil
    end

    # The archive's own stand-in for a picture it never had.
    def missing_picture?(shot) = shot.nil? || shot['thumb'].to_s.match?(%r{/NoAvail\.jpg\z}i)

    def shown_pictures(pictures) = (pictures || []).reject { |shot| shot['decoration'] }

    def card_fields(block)
      block['rows'].flat_map do |row|
        row.each_with_index.map { |value, at| [block['labels'][at], value] }
      end
    end

    # A download in a card rarely says its own size, because the card already does.
    def card_size(block)
      at = block['labels'].index { |label| label.to_s.casecmp?('size') }
      at && block['rows'].first&.[](at)
    end

    UNITS = {'k' => 1.0 / 1024, 'm' => 1.0, 'g' => 1024.0}.freeze

    def needs_pages(items)
      urls = items.filter_map { |item| item['url'] if item['kind'] == 'file' }
      Article.pages_for(urls, besides: @article&.[](:url_path))
    end

    def needs_items(items)
      found = Article.downloads_at(items.filter_map { |item| item['url'] if item['kind'] == 'page' })
      items.map do |item|
        link = found[item['url']]
        next item unless link

        item.merge('url' => link['url'], 'file' => link['file'], 'mirror' => link['mirror'], 'kind' => 'file',
          'size' => item['size'] || link['size'], 'page' => item['url'])
      end
    end

    def need_page(item, pages)
      item['page'] || (pages[item['url']] && page_url(pages[item['url']]))
    end

    def need_about(item)
      case item['kind']
      when 'file' then download_about(item)
      when 'page' then 'addon page'
      else URI(item['url']).host.to_s.delete_prefix('www.')
      end
    rescue URI::InvalidURIError
      ''
    end

    # Sizes are written as the authors wrote them: `14,2 MB`, `661 KB`, `1 Mb`.
    def needs_total(items)
      sizes = items.filter_map { |item| megabytes(item['size']) }
      return if sizes.size < 2

      total = sizes.sum
      return format('%.1f GB', total / 1024) if total >= 1024

      total >= 10 ? "#{total.round} MB" : format('%.1f MB', total)
    end

    def megabytes(size)
      found = size.to_s.match(/([\d.,]+)\s*([kmg])?b/i)
      found && (found[1].tr(',', '.').to_f * UNITS.fetch(found[2].to_s.downcase, 1.0 / 1024 / 1024))
    end

    def download_about(link, size = nil)
      mirror = link['mirror'] && "FTP##{link['mirror']}"
      [link['file'], link['size'] || size, mirror].reject { |part| part.to_s.empty? }.join(' - ')
    end

    def date(time) = time&.strftime('%-d %B %Y')

    def number(count) = count.to_i.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

    def counts = @counts ||= Article.section_counts

    def section_path_of(article) = article[:section].to_s.empty? ? '/' : "/#{article[:section]}"

    def section_label_of(article)
      Menu.label(section_path_of(article)) || article[:section_label].to_s
    end

    def trail(path) = Menu.trail(path)

    # What a search result shows under its title, read off the port like the rest of
    # this side. Escaped before the words are marked, because the port holds the text
    # decoded where the capture held it encoded.
    def excerpt(article)
      highlight(CGI.escapeHTML(Prose.excerpt(body_text(article), @query.terms)))
    end

    def body_text(article)
      blocks(article).filter_map { |block| block_text(block) }.join(' ')
    end

    def block_text(block)
      return Prose.plain(block['markdown']) if block['type'] == 'prose'

      (block['labels'] + block['rows'].flatten).join(' ') if block['type'] == 'card'
    end

    def menu_href(item) = item[:url] || (item[:path] ? page_url(item[:path]) : '#')

    def menu_active?(item) = Menu.holds?(item, nav_path)
  end
end

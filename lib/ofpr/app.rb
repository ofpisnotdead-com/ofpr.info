require 'cgi'
require 'sinatra/base'
require_relative '../ofpr'

module Ofpr
  class App < Sinatra::Base
    ARTICLE_TAIL = %r{\d+-[^/]*\z}
    # Sinatra anchors a route pattern itself, so this carries no \A or \z.
    PATH = %r{/(?<path>[A-Za-z0-9][A-Za-z0-9._/-]*)}

    NAV = File.read(File.join(Ofpr.root, 'views/nav.html')).freeze

    configure do
      set :root, Ofpr.root
      set :views, File.join(Ofpr.root, 'views')
      set :public_folder, File.join(Ofpr.root, 'public')
      set :erb, escape_html: true
      set :cdn_base, ENV.fetch('CDN_BASE', '')
      set :consent, ENV['CONSENT'] == '1'
    end

    helpers do
      def renderer = @renderer ||= Renderer.new(cdn_base: settings.cdn_base)

      def body_html(article) = renderer.call(article[:body_html])

      def pager(base, start, total) = Pager.new(base, start, total).to_html

      # Stored text keeps the entities the capture had. The browser title is the one
      # place the rebuild prints them decoded.
      def page_title = @page_title ? "OFP.info 2.5 - #{CGI.unescapeHTML(@page_title.to_s)}" : 'OFP.info 2.5'

      def canonical = @canonical || '/'

      attr_reader :meta_description

      def search_base
        "/search?searchword=#{Rack::Utils.escape(@query.word)}" \
          "&ordering=#{@query.ordering}&searchphrase=#{@query.phrase}"
      end

      def search_pager
        Pager.new(search_base, @query.offset, @total, per_page: @query.per_page,
          close_list: false).to_html
      end

      def page_counter
        pages = [(@total.to_f / @query.per_page).ceil, 1].max
        "Page #{(@query.offset / @query.per_page) + 1} of #{pages}"
      end

      # com_search marks the terms in a result title as well as in its excerpt.
      # Titles arrive from the capture with their entities already encoded, so escaping
      # again would turn &#039; into &amp;#039;.
      def highlight(text)
        marked = text.to_s
        @query.terms.each do |term|
          marked = marked.gsub(/#{Regexp.escape(term)}/i) do
            %(<span class="highlight">#{Regexp.last_match(0)}</span>)
          end
        end
        marked
      end

      def snippet(article)
        Snippet.new(article[:body_html], @query.terms,
          cloak_text: article[:cloak_text]).to_html
      end

      # The capture writes the offset out in full rather than as Z.
      def stamp(time) = time&.strftime('%FT%T+00:00')

      def article_page? = !@article.nil?

      def search_page? = !@query.nil?

      def consent? = settings.consent

      def nav = Nav.new(NAV).for_path(nav_path)

      # An article highlights the menu item it belongs to, which for a river article is
      # News and for a section article is that section.
      def author_link
        name = @article[:author].to_s
        url = @article[:author_url]
        url ? %(<a rel="author" href="#{url}">#{name}</a>) : name
      end

      # Only a news item shows its author; a section article never does.
      def river_article? = @article[:section].to_s.empty?

      def section_path = @article[:section].to_s.empty? ? '/' : "/#{@article[:section]}"

      def meta_author = (@article || @page)[:author]

      def nav_path
        return @nav_path if @nav_path
        return request.path_info unless article_page?

        @article[:section].to_s.empty? ? '/' : "/#{@article[:section]}"
      end

      def ld_json = StructuredData.new(@article || @page).to_json
    end

    # The original served the front page at both, and old links still point at the php.
    get('/') { river }
    get('/index.php') { river }

    get '/search' do
      @query = SearchQuery.new(word: params['searchword'], phrase: params['searchphrase'],
        ordering: params['ordering'], start: params['start'])
      @page_title = 'Search'
      @canonical = '/search'
      @total, @articles = Article.search(@query)
      erb :search
    end

    # Both forms post: the search page's own, and the module in the header, which posts
    # to the site root the way Joomla's index.php took it. The url contract is the get,
    # so send the browser there.
    post('/search') { search_redirect }
    post('/') { search_redirect }
    post('/index.php') { search_redirect }

    # Keeps every captured /ofpgm/ url working once the images move to the CDN. In
    # development public/ofpgm is a symlink into the mirror, and Sinatra serves that
    # before any route, so this never runs there.
    get %r{/ofpgm/(.+)} do |path|
      halt 404 if settings.cdn_base.to_s.empty?
      redirect "#{settings.cdn_base.delete_suffix('/')}/#{path}", 301
    end

    get PATH do
      path = params['path'].delete_suffix('.html')
      next serve_article("/#{path}") if ARTICLE_TAIL.match?(path)

      @page = Page.by_url("/#{path}")
      @page ? serve_page : serve_section(path)
    end

    not_found do
      content_type :html
      erb :not_found, layout: false
    end

    private

    def river
      @start = params['start'].to_i
      @page_title = 'News'
      @canonical = '/'
      @nav_path = '/'
      @articles = Article.river(start: @start)
      @total = Article.count
      erb :river
    end

    def search_redirect
      redirect "/search?searchword=#{Rack::Utils.escape(params['searchword'].to_s)}" \
               "&ordering=#{params['ordering'] || 'newest'}" \
               "&searchphrase=#{params['searchphrase'] || 'all'}", 303
    end

    def serve_page
      @page_title = @page[:title]
      @canonical = @page[:url_path]
      @meta_description = @page[:description]
      erb :page, layout: :article_layout
    end

    def serve_article(url_path)
      @article = Article.by_url(url_path)
      halt 404 unless @article

      @page_title = @article[:title]
      @canonical = @article[:url_path]
      @meta_description = @article[:description]
      erb :article, layout: :article_layout
    end

    def serve_section(name)
      @start = params['start'].to_i
      @section = name
      @page_title = name
      @canonical = "/#{name}"
      @total, @articles = Article.section(name, start: @start)
      halt 404 if @total.zero?
      erb :section
    end
  end
end

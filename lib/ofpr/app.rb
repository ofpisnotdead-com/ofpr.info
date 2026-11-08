require 'cgi'
require 'sinatra/base'
require_relative '../ofpr'
require_relative 'presenter'

module Ofpr
  class App < Sinatra::Base
    ARTICLE_TAIL = %r{\d+-[^/]*\z}
    # Sinatra anchors a route pattern itself, so this carries no \A or \z.
    PATH = %r{/(?<path>[A-Za-z0-9][A-Za-z0-9._/-]*)}

    # Where a report goes. The invite is the OFP/CWA community one that
    # ofpisnotdead.com lists; if it ever expires, that page has the current one.
    REPO = 'https://github.com/ofpisnotdead-com/ofpr.info'.freeze
    DISCORD = 'https://discord.gg/qkpsfJHcSB'.freeze

    DESCRIPTION = 'The news, the addons and the missions of the Operation Flashpoint ' \
                  'community, 2001 to 2019.'.freeze
    SHARE_CARD = '/images/share.jpg'.freeze
    # What is shared has to be a picture, and a big one: a gallery entry can link to a
    # page rather than to a picture, and the thumbnail beside it is typically 160x120,
    # which every messenger draws as a postage stamp. 2,693 articles have nothing but
    # that, so they are shared with the site's card instead.
    PICTURE = %r{\A(?:/|https?://).*\.(?:jpe?g|png|gif)\z}i

    configure do
      set :root, Ofpr.root
      set :views, File.join(Ofpr.root, 'views')
      set :public_folder, File.join(Ofpr.root, 'public')
      set :erb, escape_html: true
      set :cdn_base, ENV.fetch('CDN_BASE', '')
      # Off in production by default, which would send a 500 to the user and nothing to
      # the log. The backtrace belongs in the pod's output.
      set :dump_errors, true
    end

    helpers Presenter

    helpers do
      def pager(base, start, total) = Pager.new(base, start, total)

      # Stored text keeps the entities the capture had. The browser title is the one
      # place the rebuild prints them decoded.
      def page_title = @page_title ? "OFP.info 2.5 - #{Prose.decoded(@page_title)}" : 'OFP.info 2.5'

      def canonical = page_url(@canonical || '/')

      # The site served every page with a .html suffix except the river at the root:
      # the Wayback Machine's crawl of ofpr.info.paradoxstudio.uk has
      # `/addons/weapons.html?start=10` and `/10673-pfc-takes-over-ofp-info.html`, and
      # no extensionless article or listing at all. Requests still answer either way.
      def page_url(path) = path == '/' ? '/' : "#{path}.html"

      def meta_description = @meta_description && Prose.decoded(@meta_description)

      def search_base
        "/search.html?searchword=#{Rack::Utils.escape(@query.word)}" \
          "&ordering=#{@query.ordering}&searchphrase=#{@query.phrase}"
      end

      def search_pager
        Pager.new(search_base, @query.offset, @total, per_page: @query.per_page)
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

      # An article highlights the menu item it belongs to, which for a river article is
      # News and for a section article is that section.
      def author_link
        name = @article[:author].to_s
        url = @article[:author_url]
        url ? %(<a rel="author" href="#{url}">#{name}</a>) : name
      end

      def section_path = @article[:section].to_s.empty? ? '/' : "/#{@article[:section]}"

      # Which menu item the page belongs to: for an article, the section it sits in.
      def nav_path
        return @nav_path if @nav_path
        return request.path_info.delete_suffix('.html') unless @article

        @article[:section].to_s.empty? ? '/' : "/#{@article[:section]}"
      end

      def share_title = @page_title ? CGI.unescapeHTML(@page_title.to_s) : 'OFP.info 2.5'

      def share_description = meta_description || DESCRIPTION

      def share_type = @article || @page ? 'article' : 'website'

      # A page about one thing is shared with that thing's picture, at the size the
      # thumbnail links to. Everything else gets the site's card.
      def share_image
        shot = (@article || @page) && first_picture(@article || @page)
        full = shot && shot['full']
        absolute(full&.match?(PICTURE) ? asset(full) : SHARE_CARD)
      end

      def absolute(url) = url.start_with?('http') ? url : "#{request.base_url}#{url}"

      def ld_json = StructuredData.new(@article || @page).to_json

      def structured_data? = !(@article || @page).nil?

      # The page being reported on, so a report says which one it is about.
      def issue_url
        "#{REPO}/issues/new?body=#{Rack::Utils.escape("Page: #{request.path}\n\n")}"
      end

      def discord_url = DISCORD
    end

    # What both probes ask, and it must not touch postgres. One database stands behind
    # every pod, so making readiness depend on it would empty the service rather than
    # route around anything, and restarting ruby has never fixed a database.
    get('/healthz') { [200, {'content-type' => 'text/plain'}, "ok\n"] }

    # The original served the front page at both, and old links still point at the php.
    get('/') { river }
    get('/index.php') { river }

    # Both forms post: the search page's own, and the module in the header, which posts
    # to the site root the way Joomla's index.php took it. The url contract is the get,
    # so send the browser there.
    get('/search.html') { search }
    get('/search') { search }
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
      erb :not_found
    end

    error do
      content_type :html
      status 500
      erb :error
    end

    private

    def river
      @start = params['start'].to_i
      @page_title = 'News'
      @canonical = '/'
      @nav_path = '/'
      @articles = Article.river(start: @start)
      @total = Article.count
      @pager_base = '/'
      erb :listing
    end

    def search
      @query = SearchQuery.new(word: params['searchword'], phrase: params['searchphrase'],
        ordering: params['ordering'], start: params['start'])
      @page_title = 'Search'
      @canonical = '/search'
      @total, @articles = Article.search(@query)
      erb :search
    end

    def search_redirect
      redirect "/search.html?searchword=#{Rack::Utils.escape(params['searchword'].to_s)}" \
               "&ordering=#{params['ordering'] || 'newest'}" \
               "&searchphrase=#{params['searchphrase'] || 'all'}", 303
    end

    def serve_page
      @page_title = @page[:title]
      @canonical = @page[:url_path]
      @meta_description = @page[:description]
      erb :page
    end

    def serve_article(url_path)
      @article = Article.by_url(url_path)
      halt 404 unless @article

      @page_title = @article[:title]
      @canonical = @article[:url_path]
      @meta_description = @article[:description]
      erb :article
    end

    def serve_section(name)
      @start = params['start'].to_i
      @section = name
      @page_title = Menu.label("/#{name}") || name
      @canonical = "/#{name}"
      @total, @articles = Article.section(name, start: @start)
      return serve_group("/#{name}") if @total.zero?

      @pager_base = "/#{name}.html"
      erb :listing
    end

    # A heading the sections hang under rather than a section of its own.
    def serve_group(path)
      @children = Menu.children_of(path) or halt 404

      @page_title = Menu.label(path)
      @canonical = path
      @nav_path = path
      erb :group
    end
  end
end

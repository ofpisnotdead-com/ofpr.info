RSpec.describe 'the site', type: :request do
  def app = Ofpr::App

  describe 'the front river' do
    it 'serves the newest articles first' do
      insert_article(id: 1, url_path: '/1-older', title: 'Older', published_at: Time.utc(2003, 1, 1))
      insert_article(id: 2, url_path: '/2-newer', title: 'Newer', published_at: Time.utc(2004, 1, 1))

      get '/'

      expect(last_response).to be_ok
      expect(last_response.body.index('Newer')).to be < last_response.body.index('Older')
    end

    it 'pages ten at a time' do
      11.times { |i| insert_article(id: i + 1, url_path: "/#{i + 1}-a", title: "Article #{i}") }

      get '/', start: 10

      expect(last_response.body.scan('<article class="item">').size).to eq(1)
    end

    it 'serves the river at the url the original php used too' do
      insert_article(id: 1, url_path: '/1-a', title: 'An item')

      get '/index.php'

      expect(last_response).to be_ok
      expect(last_response.body).to include('An item')
    end
  end

  describe 'a menu page' do
    it 'renders its body' do
      insert_page(body_html: '<p>every mod</p>')

      get '/mods'

      expect(last_response).to be_ok
      expect(last_response.body).to include('every mod')
    end

    it 'is not listed in the river' do
      insert_page

      get '/'

      expect(last_response.body).not_to include('<article class="item">')
    end
  end

  describe 'an article' do
    it 'serves a root url' do
      insert_article(id: 2679, url_path: '/2679-opflashpoint-it', title: 'opflashpoint.it')

      get '/2679-opflashpoint-it'

      expect(last_response).to be_ok
      expect(last_response.body).to include('opflashpoint.it')
    end

    it 'serves a url nested under a section' do
      insert_article(id: 304, url_path: '/utilities/304-fraps-2-0-0-demo', title: 'Fraps',
        section: 'utilities')

      get '/utilities/304-fraps-2-0-0-demo'

      expect(last_response).to be_ok
      expect(last_response.body).to include('Fraps')
    end

    it 'serves an article two levels deep, where the addon database lives' do
      insert_article(id: 2232, url_path: '/addons/aircrafts/2232-franze-s-f-a-18e-f',
        title: "Franze's F/A-18E/F", section: 'addons/aircrafts')

      get '/addons/aircrafts/2232-franze-s-f-a-18e-f'

      expect(last_response).to be_ok
      expect(last_response.body).to include('F/A-18E/F')
    end

    it 'renders the body from the blocks the import read off it' do
      insert_article(body_html: '<b>bold</b> and <a href="/x.html">a link</a>')

      get '/1-a-thing'

      expect(last_response.body).to include('<strong>bold</strong>')
      expect(last_response.body).to include('<a href="/x.html">a link</a>')
    end

    it 'lays a download out from the block rather than printing its button' do
      insert_article(body_html: '<a href="https://files.ofpisnotdead.com/files/ofpd/x.rar">' \
                                '<img src="/ofpgm/images/downloadftp1.jpg"></a>')

      get '/1-a-thing'

      expect(last_response.body).to include('class="download"')
      expect(last_response.body).to include('x.rar - FTP#1')
      expect(last_response.body).not_to include('downloadftp1.jpg')
    end

    it 'answers 404 for an id it does not have' do
      get '/99999-nothing-here'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'a section listing' do
    # Joomla stored the category as the path its files sat under. The captured page
    # titles call it what the menu calls it, and so does the rebuild.
    it 'names the section the way the site named it, not the way Joomla filed it' do
      insert_article(id: 5, url_path: '/addons/vehicles/5-a-van', title: 'A van',
        section: 'addons/vehicles', section_label: 'unofaddons/vehicles')

      get '/addons/vehicles.html'

      expect(last_response.body).to include('<title>OFP.info 2.5 - Vehicles</title>')
      expect(last_response.body).not_to include('unofaddons/vehicles')
    end

    it 'leads an article with the trail the menu gives it' do
      insert_article(id: 5, url_path: '/addons/vehicles/5-a-van', title: 'A van',
        section: 'addons/vehicles', section_label: 'unofaddons/vehicles')

      get '/addons/vehicles/5-a-van.html'

      expect(last_response.body)
        .to include('<p class="crumbs">Addons / <a href="/addons/vehicles.html">Vehicles</a> / A van</p>')
    end

    it 'serves the articles of that section' do
      insert_article(id: 5, url_path: '/5-a-plane', title: 'A plane', section: 'addons/aircrafts')

      get '/addons/aircrafts'

      expect(last_response).to be_ok
      expect(last_response.body).to include('A plane')
    end

    it 'answers 404 for a section with nothing in it' do
      get '/addons/boats'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'search' do
    before do
      insert_article(id: 1, url_path: '/1-desert', title: 'Desert storm mission',
        published_at: Time.utc(2003, 1, 1))
      insert_article(id: 2, url_path: '/2-island', title: 'An island',
        body_html: '<p>a desert island</p>', published_at: Time.utc(2004, 1, 1))
    end

    it 'says how many it found' do
      get '/search', searchword: 'desert', ordering: 'newest', searchphrase: 'all'

      expect(last_response).to be_ok
      expect(last_response.body).to include('2 results for')
    end

    # `Snippet` is com_search's own excerpt and belongs to the facsimile: it strips the
    # tags without putting anything in their place, so an addon card comes out as
    # `AuthorSizeTheSun`. This side reads the excerpt off the port instead.
    it 'reads the excerpt off the port, with the cells of a card held apart' do
      insert_article(id: 3, url_path: '/3-a-van', title: 'A van', section: 'addons/vehicles',
        body_html: '<table><tr><td>Author<td>Size<tr><td><b>TheSun</b><td><b>[5,5 MB]</b></table>')

      get '/search', searchword: 'thesun'

      expect(last_response.body)
        .to include('Author Size <span class="highlight">TheSun</span> 5,5 MB')
    end

    it 'searches the body as well as the title' do
      get '/search', searchword: 'island'

      expect(last_response.body).to include('/2-island')
    end

    it 'requires every term for searchphrase=all' do
      get '/search', searchword: 'desert jungle', searchphrase: 'all'

      expect(last_response.body).to include('0 results for')
    end

    it 'takes the header module post to the search url the site served' do
      post '/', searchword: 'desert', task: 'search', option: 'com_search'

      expect(last_response.status).to eq(303)
      expect(last_response.headers['location'])
        .to end_with('/search.html?searchword=desert&ordering=newest&searchphrase=all')
    end

    # With no keyword the site still renders the form, and no result list.
    it 'renders the form and no results when given no keyword' do
      get '/search', searchword: ''

      expect(last_response.body).to include('class="finder"')
      expect(last_response.body).not_to include('results for')
      expect(last_response.body).not_to include('class="results"')
    end
  end

  describe 'the url scheme' do
    it 'links a listing and an article with the suffix the site served' do
      insert_article(id: 2232, url_path: '/addons/aircrafts/2232-franze', title: 'Franze',
        section: 'addons/aircrafts')

      get '/addons/aircrafts.html'

      expect(last_response).to be_ok
      expect(last_response.body).to include('href="/addons/aircrafts/2232-franze.html"')
    end

    it 'leaves the river at the root, which carried no suffix' do
      insert_article(id: 1, url_path: '/1-a', title: 'An item')

      get '/'

      expect(last_response.body).to include('<link href="/" rel="canonical"')
    end

    it 'still answers without the suffix' do
      insert_article(id: 2679, url_path: '/2679-opflashpoint-it', title: 'opflashpoint.it')

      get '/2679-opflashpoint-it'

      expect(last_response).to be_ok
    end
  end

  describe 'the error page' do
    it 'answers 404 with the archive own wording and somewhere to go next' do
      get '/no-such-page'

      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Nothing at that address')
      expect(last_response.body).to include('action="/search.html"')
    end
  end

  describe 'reporting a problem' do
    it 'names the page in the link, so a report says which one it is about' do
      insert_article(id: 2679, url_path: '/2679-opflashpoint-it', title: 'opflashpoint.it')

      get '/2679-opflashpoint-it.html'

      expect(last_response.body)
        .to include('https://github.com/ofpisnotdead-com/ofpr.info/issues/new' \
                    '?body=Page%3A+%2F2679-opflashpoint-it.html')
    end

    it 'sends a question to the community discord' do
      get '/'

      expect(last_response.body)
        .to include('href="https://discord.gg/qkpsfJHcSB">Ask on Discord</a>')
    end
  end

  # The site as it was, rendered from the same data through the captured templates.
  # This is what `rake compare` holds the data to, so its markup has to stay exactly
  # what the capture has.
  describe 'the facsimile' do
    it 'serves the river through the captured templates' do
      5.times { |i| insert_article(id: i + 1, url_path: "/#{i + 1}-a", title: "Article #{i}") }

      get '/archive/'

      expect(last_response).to be_ok
      expect(last_response.body).to include('id="itemListPrimary"')
      expect(last_response.body).not_to include('id="itemListSecondary"')
    end

    it 'serves an article body as the site stored it' do
      insert_article(body_html: '<b>bold</b>')

      get '/archive/1-a-thing.html'

      expect(last_response.body).to include('<b>bold</b>')
      expect(last_response.body).to include('class="itemFullText"')
    end

    it 'shows a menu page with no headline or metadata' do
      insert_page(body_html: '<p>every mod</p>')

      get '/archive/mods'

      expect(last_response.body).to include('<p>every mod</p>')
      expect(last_response.body).to match(%r{<header>\s*</header>})
    end

    it 'prints the search total the way com_search did' do
      insert_article(id: 1, url_path: '/1-desert', title: 'Desert storm mission')

      get '/archive/search', searchword: 'desert'

      expect(last_response.body).to include('Total: 1 results found.')
      expect(last_response.body).to include('id="searchForm"')
    end

    it 'serves the site own 404 page, as the Wayback Machine captured it' do
      get '/archive/no-such-page'

      expect(last_response.status).to eq(404)
      expect(Ofpr::Skeleton.of(last_response.body))
        .to eq(Ofpr::Skeleton.of(File.read(fixture_path('error-404.html'), encoding: 'UTF-8')))
    end

    it 'leaves a path that only starts with the word alone' do
      insert_article(id: 7, url_path: '/7-archived', title: 'Archived')

      get '/7-archived.html'

      expect(last_response).to be_ok
      expect(last_response.body).to include('class="panel"')
    end
  end

  describe 'the image path' do
    it 'redirects a captured ofpgm url to the cdn' do
      Ofpr::App.set(:cdn_base, 'https://files.example.com/ofpr')

      get '/ofpgm/news/pics2/frapss.jpg'

      expect(last_response.status).to eq(301)
      expect(last_response['Location']).to eq('https://files.example.com/ofpr/news/pics2/frapss.jpg')
    ensure
      Ofpr::App.set(:cdn_base, '')
    end

    it 'answers 404 when no cdn is configured' do
      get '/ofpgm/news/pics2/frapss.jpg'

      expect(last_response.status).to eq(404)
    end
  end
end

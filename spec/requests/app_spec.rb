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

  describe 'what a page says when it is shared' do
    it 'shares an article with its own picture, at full size' do
      insert_article(id: 1, url_path: '/1-a', title: 'A thing',
        body_html: '<a href="/ofpgm/big.jpg"><img src="/ofpgm/small.jpg"></a>')

      get '/1-a.html'

      expect(last_response.body).to include('<meta property="og:image" content="http://example.org/ofpgm/big.jpg">')
      expect(last_response.body).to include('<meta property="og:type" content="article">')
    end

    it 'shares the site card rather than a thumbnail with nothing behind it' do
      insert_page(body_html: '<a href="/mods.html#one"><img src="/ofpgm/mods-shot.gif"></a>')

      get '/mods.html'

      expect(last_response.body).to include('<meta property="og:image" content="http://example.org/images/share.jpg">')
    end

    it 'decodes text the capture encoded twice' do
      insert_page(description: 'Click a mod&amp;#39;s banner')

      get '/mods.html'

      expect(last_response.body).to include('Click a mod&#39;s banner')
      expect(last_response.body).not_to include('&amp;#39;')
    end

    it 'decodes the named entities CGI leaves alone' do
      insert_page(description: 'Spooner[541 kB] &amp;nbsp; FTP#2')

      get '/mods.html'

      expect(last_response.body).to include("Spooner[541 kB] \u00A0 FTP#2")
      expect(last_response.body).not_to include('nbsp')
    end

    it 'shares the site card and the site description on a listing' do
      insert_article(id: 1, url_path: '/1-a', title: 'A thing')

      get '/'

      expect(last_response.body).to include('<meta property="og:image" content="http://example.org/images/share.jpg">')
      expect(last_response.body).to include('<meta property="og:type" content="website">')
      expect(last_response.body).to include(Ofpr::App::DESCRIPTION)
      expect(last_response.body).to include('content="News - The Operation Flashpoint archive"')
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
        .to include('<p class="crumbs"><a href="/addons.html">Addons</a> / ' \
                    '<a href="/addons/vehicles.html">Vehicles</a> / A van</p>')
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

  # Addons and Missions hold no articles of their own, so without these the two
  # headings in the menu would be the only items that go nowhere.
  describe 'a menu group' do
    it 'lists the sections that hang under it, with their counts' do
      insert_article(id: 5, url_path: '/addons/vehicles/5-a-van', title: 'A van',
        section: 'addons/vehicles')

      get '/addons.html'

      expect(last_response).to be_ok
      expect(last_response.body).to include('<title>OFP.info 2.5 - Addons</title>')
      expect(last_response.body).to include('href="/addons/vehicles.html"')
      expect(last_response.body).to include('Weapons')
    end

    it 'answers 404 for a path that is neither a group nor a section' do
      get '/nothing-like-that.html'

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

    it 'pages through the results with the query kept' do
      (3..7).each do |id|
        insert_article(id: id, url_path: "/#{id}-sand", title: "Desert sand #{id}",
          published_at: Time.utc(2005, 1, id))
      end

      get '/search', searchword: 'desert', ordering: 'oldest', searchphrase: 'all'
      next_url = last_response.body[/href="([^"]*)">Next/, 1]
      get CGI.unescapeHTML(next_url)

      expect(last_response.body).to include('Page 2 of 2')
      expect(last_response.body).to include('sand 7')
    end

    it 'shows as many results a page as asked, and keeps the size in the page links' do
      (3..13).each do |id|
        insert_article(id: id, url_path: "/#{id}-sand", title: "Desert sand #{id}",
          published_at: Time.utc(2005, 1, id))
      end

      get '/search', searchword: 'desert'
      expect(last_response.body).to include('searchphrase=all&amp;start=5">Next')

      get '/search', searchword: 'desert', limit: '10'
      expect(last_response.body.scan('class="result"').size).to eq(10)
      expect(last_response.body).to include('&amp;limit=10&amp;start=10">Next')
      expect(last_response.body).to include('<option value="10" selected>')
    end

    # The stored html has no spaces between an addon card's cells, so an excerpt taken
    # from it comes out as `AuthorSizeTheSun`. The port holds them apart.
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

  describe 'the failure page' do
    # Specs let exceptions through so a failing example shows its backtrace; production
    # does not, and this is what it serves instead.
    it 'serves the site own page when something raises' do
      allow(Ofpr::Article).to receive(:river).and_raise('the database went away')
      Ofpr::App.set(:raise_errors, false)
      Ofpr::App.set(:show_exceptions, false)

      get '/'

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('Something went wrong')
    ensure
      Ofpr::App.set(:raise_errors, true)
      Ofpr::App.set(:show_exceptions, false)
    end
  end

  describe 'the health endpoint' do
    # A pod that cannot reach postgres should still answer the probe, so this must not
    # touch the database.
    it 'answers without asking the database anything' do
      allow(Ofpr::Article).to receive(:dataset).and_raise('the database is gone')

      get '/healthz'

      expect(last_response).to be_ok
      expect(last_response.body).to eq("ok\n")
    end
  end

  describe 'the picture path' do
    it 'points a picture straight at the cdn rather than at the redirect' do
      insert_article(body_html: '<img src="/ofpgm/news/a.jpg">')
      Ofpr::App.set(:cdn_base, 'https://files.example.com/files/ofpgm')

      get '/1-a-thing.html'

      expect(last_response.body).to include('src="https://files.example.com/files/ofpgm/news/a.jpg"')
    ensure
      Ofpr::App.set(:cdn_base, '')
    end

    it 'leaves the path alone when no cdn is configured' do
      insert_article(body_html: '<img src="/ofpgm/news/a.jpg">')

      get '/1-a-thing.html'

      expect(last_response.body).to include('src="/ofpgm/news/a.jpg"')
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

  describe 'a withdrawn article' do
    it 'answers 410 at its url, under any slug, and from its old id' do
      insert_old_id(10_849, 9858)

      ['/9858-area-51-mod-busted.html', '/9858-renamed.html'].each do |path|
        get path

        expect(last_response.status).to eq(410)
        expect(last_response.body).to include('This article is private')
      end

      get '/index.php', showthis: '10849'
      expect(last_response.status).to eq(410)
    end
  end

  describe 'a link kept from the old site' do
    it 'sends an old id to the article the archive serves now' do
      insert_article(id: 9845, url_path: '/9845-a-thing')
      insert_old_id(10_834, 9845)

      get '/index.php', showthis: '10834'

      expect(last_response.status).to eq(301)
      expect(last_response['Location']).to end_with('/9845-a-thing.html')
    end

    it 'answers 404 for an old id the archive does not carry' do
      insert_old_id(2282)

      get '/index.php', showthis: '2282'

      expect(last_response.status).to eq(404)
    end

    it 'sends a bare url to the section the article sits in' do
      insert_article(id: 1978, section: 'addons/aircrafts',
        url_path: '/addons/aircrafts/1978-coast-guard')

      get '/1978-coast-guard.html'

      expect(last_response.status).to eq(301)
      expect(last_response['Location']).to end_with('/addons/aircrafts/1978-coast-guard.html')
    end

    it 'takes the id as the address when the slug and the section disagree with it' do
      insert_article(id: 1978, url_path: '/1978-coast-guard')

      get '/addons/units/1978-whatever-was-typed.html'

      expect(last_response.status).to eq(301)
      expect(last_response['Location']).to end_with('/1978-coast-guard.html')
    end

    it 'answers 404 for an id no article has' do
      get '/4242-nothing-here.html'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'the converter' do
    it 'answers a pasted old link with the url that replaced it' do
      insert_article(id: 9845, url_path: '/9845-a-thing', title: 'A thing')
      insert_old_id(10_834, 9845)

      get '/convert.html', link: 'http://ofp.gamepark.cz/index.php?showthis=10834'

      expect(last_response).to be_ok
      expect(last_response.body).to include('/9845-a-thing.html')
      expect(last_response.body).to include('Old id <strong>10834</strong>')
    end

    it 'says what became of an article the archive left out' do
      insert_old_id(2282)

      get '/convert.html', link: '2282'

      expect(last_response.body).to include('does not carry it')
    end

    it 'offers the form on its own' do
      get '/convert.html'

      expect(last_response).to be_ok
      expect(last_response.body).to include('name="link"')
    end
  end
end

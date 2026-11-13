require 'tmpdir'

RSpec.describe 'a site once hosted on gamepark', type: :request do
  def app = Ofpr::App

  let(:root) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(root, 'site/news'))
    File.write(File.join(root, 'site/news/12.html'), '<p>post</p>')
    FileUtils.mkdir_p(File.join(root, 'site/bhd'))
    File.write(File.join(root, 'site/bhd/index.html'), '<p>blog</p>')
    File.write(File.join(root, 'map.tsv'), <<~TSV)
      news.php?readmore=12\tnews/12.html
      BHD_MOD/forum/showthread.php?t=9\tbhd/forum/9.html
      BHD_MOD/*\tbhd/index.html
      *\tindex.html
    TSV
    site = Ofpr::Hosted.new(File.join(root, 'map.tsv'), File.join(root, 'site'))
    allow(Ofpr::Hosted).to receive(:[]).and_return(nil)
    allow(Ofpr::Hosted).to receive(:[]).with('ofpmm').and_return(site)
  end

  after { FileUtils.rm_rf(root) }

  it 'sends an old address to the page that stands in for it, on the same host' do
    get '/_hosted/ofpmm/news.php?readmore=12'

    expect(last_response.status).to eq(301)
    expect(last_response.location).to eq('http://example.org/_hosted/ofpmm/news/12.html')
  end

  it 'reads past the session id a forum wrote into its links' do
    get "/_hosted/ofpmm/BHD_MOD/forum/showthread.php?s=#{'c6' * 16}&t=9"

    expect(last_response.location).to end_with('/_hosted/ofpmm/bhd/forum/9.html')
  end

  it 'sends an old address it has no page for to the page of its part of the site' do
    get '/_hosted/ofpmm/BHD_MOD/forum/member.php?u=3'
    expect(last_response.location).to end_with('/_hosted/ofpmm/bhd/index.html')

    get '/_hosted/ofpmm/profile.php?lookup=7'
    expect(last_response.location).to end_with('/_hosted/ofpmm/index.html')
  end

  it 'serves the index of a folder of the rebuild at the folder, and sends a folder it lacks on' do
    get '/_hosted/ofpmm/bhd/'
    expect(last_response.body).to eq('<p>blog</p>')

    get '/_hosted/ofpmm/BHD_MOD/'
    expect(last_response.location).to end_with('/_hosted/ofpmm/bhd/index.html')
  end

  it 'serves a file of the rebuild from its backend at the address asked for, leaving its encoding to it' do
    get '/_hosted/ofpmm/news/12.html'

    expect(last_response).to be_ok
    expect(last_response.body).to eq('<p>post</p>')
    expect(last_response.content_type).to eq('text/html')
  end

  it 'names the type of a file its backend sends as plain bytes by its name' do
    site = Ofpr::Hosted.new(File.join(root, 'map.tsv'), 'https://files.example')

    expect(site.send(:typed, 'application/octet-stream', 'avoncalling.wav')).to eq('audio/x-wav')
    expect(site.send(:typed, 'application/octet-stream', 'data.bin')).to eq('application/octet-stream')
    expect(site.send(:typed, 'text/html', 'news.htm')).to eq('text/html')
  end

  it 'finds a site in its folder under the base, unless the site has a backend of its own' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('HOSTED_BASE', '').and_return('https://files.example/_hosted/')

    expect(Ofpr::Hosted.base('theofpfaq')).to eq('https://files.example/_hosted/theofpfaq')
  end

  it 'answers 404 for a file the backend does not have, or one outside it' do
    get '/_hosted/ofpmm/news/13.html'
    expect(last_response.status).to eq(404)

    get '/_hosted/ofpmm/news/%2e%2e/%2e%2e/map.tsv'
    expect(last_response.status).to eq(404)
  end

  it 'answers 404 for a site it does not know' do
    get '/_hosted/other/index.html'

    expect(last_response.status).to eq(404)
  end

  it 'follows a link written against the mirror of gamepark to the site' do
    get '/ofpgm/_hosted/ofpmm/news.php?readmore=12'

    expect(last_response.location).to eq('http://example.org/_hosted/ofpmm/news.php?readmore=12')
  end
end

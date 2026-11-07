RSpec.describe Ofpr::Renderer do
  it 'leaves asset paths alone when no cdn is configured' do
    html = '<img src="/ofpgm/news/pics2/frapss.jpg">'

    expect(described_class.new.call(html)).to eq(html)
  end

  it 'moves asset paths to the cdn' do
    html = '<img src="/ofpgm/news/pics2/frapss.jpg">'

    expect(described_class.new(cdn_base: 'https://files.example.com/ofpr').call(html))
      .to eq('<img src="https://files.example.com/ofpr/news/pics2/frapss.jpg">')
  end

  it 'tolerates a trailing slash on the cdn base' do
    html = '<a href="/ofpgm/a.jpg">x</a>'

    expect(described_class.new(cdn_base: 'https://files.example.com/ofpr/').call(html))
      .to eq('<a href="https://files.example.com/ofpr/a.jpg">x</a>')
  end

  # The rebuild's markup carries line breaks inside attribute values; a browser drops
  # them from the url, and reading one literally invents a filename nobody ever had.
  it 'drops line breaks from inside an asset path' do
    html = %(<img src="/ofpgm/news/pics/sectionpics/\r\nADFBrowning.jpg">)

    expect(described_class.new.call(html))
      .to eq('<img src="/ofpgm/news/pics/sectionpics/ADFBrowning.jpg">')
  end

  # An article two levels deep references ../../ofpgm/x.jpg, which resolves to the same
  # file; normalising it means one asset form reaches the cdn rewrite.
  it 'normalises a relative asset path to the absolute one' do
    html = '<img src="../../ofpgm/images/download.jpg">'

    expect(described_class.new.call(html))
      .to eq('<img src="/ofpgm/images/download.jpg">')
  end

  it 'moves a relative asset path to the cdn too' do
    html = '<img src="../ofpgm/images/download.jpg">'

    expect(described_class.new(cdn_base: 'https://files.example.com/ofpr').call(html))
      .to eq('<img src="https://files.example.com/ofpr/images/download.jpg">')
  end

  it 'drops the old host a few captures wrote into their image urls' do
    html = '<IMG src="http://ofpr.info.paradoxstudio.uk/ofpgm/news/pics/meekv21s.jpg">'

    expect(described_class.new(cdn_base: '').call(html))
      .to eq('<IMG src="/ofpgm/news/pics/meekv21s.jpg">')
    expect(described_class.new(cdn_base: 'https://files.example.com/ofpr').call(html))
      .to eq('<IMG src="https://files.example.com/ofpr/news/pics/meekv21s.jpg">')
  end

  it 'leaves markup that references nothing under ofpgm' do
    html = '<a href="http://www.opflashpoint.it/">x</a>'

    expect(described_class.new(cdn_base: 'https://files.example.com').call(html)).to eq(html)
  end
end

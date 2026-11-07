RSpec.describe Ofpr::Extractor do
  it 'reads a nested article and keeps the url the site serves it at' do
    row = described_class.call(fixture_path('utilities/304-fraps-2-0-0-demo.html'), root: fixture_root)

    expect(row.id).to eq(304)
    expect(row.url_path).to eq('/utilities/304-fraps-2-0-0-demo')
    expect(row.section).to eq('utilities')
    expect(row.author).to eq('Cervo')
  end

  it 'strips the site title the rebuild prepends to every headline' do
    row = described_class.call(fixture_path('utilities/304-fraps-2-0-0-demo.html'), root: fixture_root)

    expect(row.title).to eq('Fraps 2.0.0 demo')
  end

  it 'keeps the body markup and its asset paths' do
    row = described_class.call(fixture_path('utilities/304-fraps-2-0-0-demo.html'), root: fixture_root)

    expect(row.body_html).to include('/ofpgm/news/pics2/frapss.jpg')
    expect(row.body_html).not_to include('itemLinks')
  end

  it 'parses the published and modified timestamps' do
    row = described_class.call(fixture_path('utilities/304-fraps-2-0-0-demo.html'), root: fixture_root)

    expect(row.published_at).to eq(Time.parse('2004-03-07 15:16:30 UTC'))
    expect(row.modified_at).to eq(Time.parse('2018-06-08 20:29:57 UTC'))
  end

  it 'reads a root article' do
    row = described_class.call(fixture_path('2679-opflashpoint-it.html'), root: fixture_root)

    expect(row.id).to eq(2679)
    expect(row.url_path).to eq('/2679-opflashpoint-it')
    expect(row.slug).to eq('opflashpoint-it')
  end

  # Joomla writes article titles into the ld+json block without escaping them, so a
  # title holding a backslash makes the block invalid JSON. One page in 7,454 does.
  it 'recovers a page whose ld+json carries an unescaped backslash' do
    row = described_class.call(fixture_path('8244-orcs-t80um-t90-pack.html'), root: fixture_root)

    expect(row.id).to eq(8244)
    expect(row.title).to eq('ORCS T80UM\T90 pack')
    expect(row.body_html).not_to be_empty
  end

  it 'refuses a page the capture left empty' do
    expect { described_class.call(fixture_path('2510-xmas-gift-from-bis.html'), root: fixture_root) }
      .to raise_error(described_class::Invalid, /empty/)
  end
end

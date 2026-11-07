RSpec.describe Ofpr::Article do
  it 'finds an article by the url the site serves it at' do
    insert_article(url_path: '/1-a-thing')

    expect(described_class.by_url('/1-a-thing')[:id]).to eq(1)
  end

  it 'orders the river newest first and pages by ten' do
    12.times { |i| insert_article(id: i + 1, url_path: "/#{i + 1}-a", published_at: Time.utc(2000 + i, 1, 1)) }

    expect(described_class.river.size).to eq(10)
    expect(described_class.river.first[:id]).to eq(12)
    expect(described_class.river(start: 10).size).to eq(2)
  end

  it 'keeps a sectioned article out of the river and orders it by id, not by date' do
    insert_article(id: 1, url_path: '/1-a', published_at: Time.utc(2009, 1, 1))
    insert_article(id: 2, url_path: '/2-b', published_at: Time.utc(2001, 1, 1))
    insert_article(id: 3, url_path: '/addons/units/3-c', section: 'addons/units')

    expect(described_class.river.map { |row| row[:id] }).to eq([2, 1])
  end

  it 'counts a section alongside its page' do
    insert_article(id: 1, url_path: '/1-a', section: 'addons/units')
    insert_article(id: 2, url_path: '/2-b', section: 'addons/units')
    insert_article(id: 3, url_path: '/3-c', section: 'news')

    total, page = described_class.section('addons/units')

    expect(total).to eq(2)
    expect(page.size).to eq(2)
  end

  it 'returns nothing for a blank search' do
    expect(described_class.search(Ofpr::SearchQuery.new(word: ''))).to eq([0, []])
  end
end

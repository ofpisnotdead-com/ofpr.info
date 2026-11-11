RSpec.describe Ofpr::SearchQuery do
  it 'defaults to the parameters the rebuild puts in its own urls' do
    query = described_class.new(word: 'fliper')

    expect(query.phrase).to eq('all')
    expect(query.ordering).to eq('newest')
    expect(query.start).to eq(0)
  end

  it 'treats every term as required for searchphrase=all' do
    expect(described_class.new(word: 'desert storm', phrase: 'all').tsquery)
      .to eq('desert & storm')
  end

  it 'accepts any term for searchphrase=any' do
    expect(described_class.new(word: 'desert storm', phrase: 'any').tsquery)
      .to eq('desert | storm')
  end

  it 'requires adjacency for searchphrase=exact' do
    expect(described_class.new(word: 'desert storm', phrase: 'exact').tsquery)
      .to eq('desert <-> storm')
  end

  it 'falls back to all for an ordering or phrase it does not know' do
    query = described_class.new(word: 'x', phrase: 'sideways', ordering: 'loudest')

    expect(query.phrase).to eq('all')
    expect(query.ordering).to eq('newest')
  end

  it 'is blank without a word, and has no query to run' do
    query = described_class.new(word: '  ')

    expect(query).to be_blank
    expect(query.tsquery).to be_nil
  end

  it 'drops punctuation rather than feeding it to tsquery' do
    expect(described_class.new(word: 'o&&fp !info').tsquery).to eq('o & fp & info')
  end

  it 'takes one of the page sizes the display selector offered, and ten otherwise' do
    expect(described_class.new(word: 'x', limit: '50').per_page).to eq(50)
    expect(described_class.new(word: 'x', limit: '7').per_page).to eq(10)
    expect(described_class.new(word: 'x', limit: '0').per_page).to eq(10)
  end

  # Joomla rounds an off-boundary start down.
  it 'rounds start down to a page boundary' do
    expect(described_class.new(word: 'x', start: 12).offset).to eq(10)
    expect(described_class.new(word: 'x', start: -5).offset).to eq(0)
  end
end

require_relative 'spec_helper'

RSpec.describe Ofpr::Conversion do
  describe '.of' do
    it 'reads the id out of a link the old site served' do
      insert_article(id: 9845, url_path: '/9845-a-thing')
      insert_old_id(10_834, 9845)

      result = described_class.of('http://ofp.gamepark.cz/index.php?showthis=10834')

      expect(result).to be_found
      expect(result.old_id).to eq(10_834)
      expect(result.article[:url_path]).to eq('/9845-a-thing')
    end

    it 'takes the old number on its own' do
      insert_article(id: 9845, url_path: '/9845-a-thing')
      insert_old_id(10_834, 9845)

      expect(described_class.of(' 10834 ').article[:id]).to eq(9845)
    end

    it 'takes a url the archive serves now, at any depth' do
      insert_article(id: 1978, url_path: '/addons/aircrafts/1978-coast-guard')

      result = described_class.of('https://ofpr.info/1978-coast-guard.html')

      expect(result).to be_found
      expect(result.old_id).to be_nil
      expect(result.article[:url_path]).to eq('/addons/aircrafts/1978-coast-guard')
    end

    it 'says so when the old site had the article and the archive does not' do
      insert_old_id(2282)

      expect(described_class.of('index.php?showthis=2282').kind).to eq(:dropped)
    end

    it 'gives the new id even where the database does not hold the article' do
      insert_old_id(10_834, 9845)

      result = described_class.of('index.php?showthis=10834')

      expect(result.kind).to eq(:absent)
      expect(result.article_id).to eq(9845)
    end

    it 'says so when nothing answers to the id at all' do
      expect(described_class.of('index.php?showthis=99999').kind).to eq(:unknown)
    end

    it 'says so when there is no id in what was pasted' do
      expect(described_class.of('http://ofp.gamepark.cz/').kind).to eq(:unreadable)
      expect(described_class.of('').kind).to eq(:empty)
    end
  end
end

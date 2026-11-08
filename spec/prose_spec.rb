require_relative '../lib/ofpr/prose'

RSpec.describe Ofpr::Prose do
  describe '.plain' do
    it 'keeps a link text and drops the url' do
      expect(described_class.plain('see the [**BIS forums**](http://x.example/t?id=1) today'))
        .to eq('see the BIS forums today')
    end

    # `[OFrP Pack [12.51 MB]](url)` is how these labels carry a size.
    it 'reads a label that holds brackets of its own' do
      markdown = 'Needed: [OFrP Weapons Pack [12.51 MB]](https://files.example/a.rar) and more'

      expect(described_class.plain(markdown))
        .to eq('Needed: OFrP Weapons Pack [12.51 MB] and more')
    end

    it 'drops a picture and cuts at a word' do
      markdown = "![](/ofpgm/a.jpg) #{'word ' * 50}"

      expect(described_class.plain(markdown, limit: 40)).to eq("#{'word ' * 7}word...")
    end
  end

  describe '.heading_id' do
    it 'gives the id the renderer will give the heading' do
      expect(described_class.heading_id('BAS Tonal Island + OPFOR')).to eq('bas-tonal-island--opfor')
    end
  end
end

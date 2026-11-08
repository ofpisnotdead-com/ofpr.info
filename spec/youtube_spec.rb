require_relative '../lib/ofpr/youtube'

RSpec.describe Ofpr::Youtube do
  def prose(markdown) = {'type' => 'prose', 'markdown' => markdown}

  it 'reads a video off a watch link, a flash url and a short link' do
    markdown = '[a](http://fr.youtube.com/watch?v=AvanSfhNaPU) http://www.youtube.com/v/tPzvQRzPZtU&rel=1 ' \
               '[b](https://youtu.be/kbHXMC2P-wg) [c](http://www.youtube.com/profile?user=Invasion1944)'

    expect(described_class.ids(markdown)).to eq(%w[AvanSfhNaPU tPzvQRzPZtU kbHXMC2P-wg])
  end

  it 'puts each video after the prose naming it, once, and runs again unchanged' do
    blocks = [prose('[one](http://youtube.com/watch?v=kbHXMC2P-wg)'),
              prose('[two](http://www.youtube.com/v/BL4aEYbJvf4) [again](http://youtube.com/watch?v=kbHXMC2P-wg)')]

    embedded = described_class.embed(blocks)

    expect(embedded).to eq([blocks[0], {'type' => 'video', 'id' => 'kbHXMC2P-wg'},
                            blocks[1], {'type' => 'video', 'id' => 'BL4aEYbJvf4'}])
    expect(described_class.embed(embedded)).to eq(embedded)
  end
end

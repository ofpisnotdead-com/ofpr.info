require_relative '../lib/ofpr/youtube'

RSpec.describe Ofpr::Youtube do
  it 'reads a video off a watch link, a flash url and a short link' do
    markdown = '[a](http://fr.youtube.com/watch?v=AvanSfhNaPU) http://www.youtube.com/v/tPzvQRzPZtU&rel=1 ' \
               '[b](https://youtu.be/kbHXMC2P-wg) [c](http://www.youtube.com/profile?user=Invasion1944)'

    expect(described_class.ids(markdown)).to eq(%w[AvanSfhNaPU tPzvQRzPZtU kbHXMC2P-wg])
  end

  it 'puts a player in place of a line that is only a link to a video' do
    line = '**[WATCH ON YouTube](http://www.youtube.com/watch?v=qY27n0db3bA)**'

    expect(described_class.split("Out now.\n#{line}"))
      .to eq(['Out now.', {type: 'video', id: 'qY27n0db3bA', markdown: line}])
  end

  it 'moves the emphasis a video line closed onto the line before it' do
    chunk = "**[DOWNLOAD](https://files.ofpisnotdead.com/a.wmv)  \n" \
            '[Watch the first part on Youtube](http://youtube.com/watch?v=kbHXMC2P-wg)**'

    expect(described_class.split(chunk).first).to eq('**[DOWNLOAD](https://files.ofpisnotdead.com/a.wmv)**')
  end

  it 'leaves a video named in a sentence, and a link to a channel, where they are' do
    chunk = 'Watch it [here](http://www.youtube.com/watch?v=nv1dye2JSHw) or on ' \
            '[YouTube](http://www.youtube.com/profile?user=Invasion1944).'

    expect(described_class.split(chunk)).to eq([chunk])
  end
end

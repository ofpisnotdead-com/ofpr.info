require_relative '../lib/ofpr/port'

RSpec.describe Ofpr::Port do
  it 'passes a body whose links and words all survive' do
    html = '<center><b>Kegetys</b> released <a href="/x.zip">the addon</a>' \
           '<img src="/ofpgm/a.jpg"></center>'

    expect(described_class.check(html)).to be_empty
  end

  it 'names a link the markdown no longer points at' do
    allow(Ofpr::Markdown).to receive(:of).and_return('nothing but words')

    expect(described_class.check('<a href="/x.zip">the addon</a>'))
      .to eq(['lost links in the markdown "/x.zip"',
              'lost words in the markdown "the", "addon" and invented "nothing", "but", "words"'])
  end

  it 'says when the markdown on record is not what the rules write now' do
    expect(described_class.check('<b>one</b>', stored: '*one*'))
      .to eq(['the stored markdown is not what these rules write'])
  end

  it 'notices a picture that did not come through' do
    allow(Ofpr::Markdown).to receive(:of).and_return('![](/ofpgm/a.jpg) ![](/ofpgm/b.jpg)')

    expect(described_class.check('<img src="/ofpgm/a.jpg">'))
      .to include('1 pictures became 2 in the markdown')
  end
end

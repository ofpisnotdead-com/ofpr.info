require_relative '../lib/ofpr/blocks'

RSpec.describe Ofpr::Blocks do
  def convert(markdown) = described_class.of(markdown)

  let(:card) do
    <<~MARKDOWN
      [![](/ofpgm/shots/East73s.jpg)](/ofpgm/shots/East73.jpg)

      | Author | Size |
      | --- | --- |
      | **Miles Teg & Co.** | **[6.99 MB]** |

      [![](/ofpgm/images/downloadftp1.jpg)](https://files.ofpisnotdead.com/files/ofpd/73eastings.rar)
    MARKDOWN
  end

  it 'reads the screenshot, the table and the download as one card' do
    expect(convert(card)).to eq([{
      type: 'card',
      picture: {thumb: '/ofpgm/shots/East73s.jpg', full: '/ofpgm/shots/East73.jpg',
                alt: '', decoration: false},
      downloads: [{url: 'https://files.ofpisnotdead.com/files/ofpd/73eastings.rar',
                   label: '', file: '73eastings.rar', size: nil, mirror: 1,
                   button: '/ofpgm/images/downloadftp1.jpg'}],
      labels: %w[Author Size],
      rows: [['Miles Teg & Co.', '6.99 MB']]
    }])
  end

  it 'reads the file, the size and the mirror off a download that says them' do
    markdown = '[**DOWNLOAD (FTP#2) - WW2 Beach Obstacles [1,8 MB]**]' \
               '(https://files.ofpisnotdead.com/files/ofpd/WW2BeachObstacles.rar)'

    expect(convert(markdown).first[:links].first)
      .to eq(url: 'https://files.ofpisnotdead.com/files/ofpd/WW2BeachObstacles.rar',
        label: 'DOWNLOAD (FTP#2) - WW2 Beach Obstacles [1,8 MB]',
        file: 'WW2BeachObstacles.rar', size: '1,8 MB', mirror: 2, button: nil)
  end

  it 'keeps a run of thumbnails together and marks the site furniture' do
    markdown = "[![](/ofpgm/a_s.jpg)](/ofpgm/a.jpg) [![](/ofpgm/b_s.jpg)](/ofpgm/b.jpg)\n\n" \
               '![](/ofpgm/images/separator.gif)'

    galleries = convert(markdown)
    expect(galleries.map { |block| block[:pictures].size }).to eq([2, 1])
    expect(galleries.map { |block| block[:pictures].map { |shot| shot[:decoration] } })
      .to eq([[false, false], [true]])
  end

  it 'takes the head row as data when it is emphasised rather than a label' do
    markdown = "| **Spanky-G** | **[2 MB]** |\n| --- | --- |\n| Everon | Czech |"

    expect(convert(markdown).first).to include(labels: [], rows: [['Spanky-G', '2 MB'],
                                                                  %w[Everon Czech]])
  end

  it 'leaves a link carrying a picture and a line of text as prose' do
    markdown = "[![](/ofpgm/cooleditor.jpg)  \nDownload [8.34MB]](</utilities/Cool Editor.zip>)"

    expect(convert(markdown).map { |block| block[:type] }).to eq(['prose'])
  end

  it 'leaves a download somebody else hosts as prose' do
    markdown = '[**the mod**](http://www.ofp.bmj.pl/rozne/Reap_Mushrooms1.rar)'

    expect(convert(markdown).map { |block| block[:type] }).to eq(['prose'])
  end

  it 'splits paragraphs that a pair of line breaks separates' do
    markdown = "a sentence  \n  \n![](/ofpgm/a.jpg)"

    expect(convert(markdown).map { |block| block[:type] }).to eq(%w[prose gallery])
  end
end

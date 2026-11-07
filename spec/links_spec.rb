RSpec.describe Ofpr::Links do
  def repair(html) = described_class.repair(html)

  it 'moves a download off the host that is gone' do
    html = '<a href="http://ftp.armedassault.info/ofpd/unofaddons0/x.zip">our site</a>'

    expect(repair(html))
      .to eq('<a href="https://files.ofpisnotdead.com/files/ofpd/unofaddons0/x.zip">our site</a>')
  end

  it 'keeps the wording and drops the mirror pointer beside it' do
    html = '<a href="http://ftp.armedassault.info/ofpd/x.zip">our site</a> &nbsp; ' \
           '<small><a href="http://files.ofpisnotdead.com/files/ofpd/x.zip">FTP#2</a></small>'

    expect(repair(html))
      .to eq('<a href="https://files.ofpisnotdead.com/files/ofpd/x.zip">our site</a>')
  end

  it 'writes the surviving links to https' do
    html = '<a href="http://files.ofpisnotdead.com/files/ofpd/x.zip">only link</a>'

    expect(repair(html)).to include('https://files.ofpisnotdead.com/files/ofpd/x.zip')
  end

  it 'leaves a file with one link alone even when that link is a pointer' do
    html = '<a href="http://ftp.armedassault.info/ofpd/x.zip">FTP#1</a>'

    expect(repair(html))
      .to eq('<a href="https://files.ofpisnotdead.com/files/ofpd/x.zip">FTP#1</a>')
  end

  it 'keeps one link when both of them are pointers' do
    html = '<a href="http://ftp.armedassault.info/ofpd/x.zip">FTP#1</a> or ' \
           '<a href="http://files.ofpisnotdead.com/files/ofpd/x.zip">FTP#2</a>'

    expect(repair(html).scan('<a ').size).to eq(1)
  end

  it 'leaves two links on different files' do
    html = '<a href="http://ftp.armedassault.info/ofpd/a.zip">FTP#2</a>' \
           '<a href="http://ftp.armedassault.info/ofpd/b.zip">FTP#2</a>'

    expect(repair(html).scan('<a ').size).to eq(2)
  end

  it 'takes the emptied wrapper with it' do
    html = '<center><a href="http://files.ofpisnotdead.com/files/ofpd/x.zip">FTP#2</a></center>' \
           '<a href="http://ftp.armedassault.info/ofpd/x.zip">the pack</a>'

    expect(repair(html)).not_to include('<center>')
  end

  it 'leaves the armedassault website alone' do
    html = '<a href="http://www.armedassault.info/news">news</a>'

    expect(repair(html)).to eq(html)
  end
end

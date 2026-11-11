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

  it 'drops a mirror pointer written with its address unquoted' do
    html = '<center>from <a href="http://ftp.armedassault.info/ofpd/x.zip"><b>FTP#1</b></a> or ' \
           '<a href=http://files.ofpisnotdead.com/files/ofpd/x.zip>FTP#2</a></center>'

    expect(repair(html)).to eq('<center>from <a href="https://files.ofpisnotdead.com/files/ofpd/x.zip"><b>FTP#1</b></a></center>')
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

  it 'keeps the link of a file needed again further down' do
    pair = '<a href="http://ftp.armedassault.info/ofpd/jam.rar">FTP#1</a> ' \
           '<small><a href="http://files.ofpisnotdead.com/files/ofpd/jam.rar">FTP#2</a></small>'
    html = "JAM3 from #{pair}<br>Pack from <a href=\"http://ftp.armedassault.info/ofpd/p.zip\">FTP#1</a>" \
           "<br>JAM 3 from #{pair}"

    expect(repair(html).scan('jam.rar').size).to eq(2)
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

  describe 'a file the archive keeps under another path' do
    before { allow(described_class).to receive(:moved).and_return(moved) }

    let(:moved) { {'ofpd/islands/Normandy.zip' => 'ofpd/islands/normandy.zip'} }

    it 'points the link at the path it is served from' do
      html = '<a href="https://files.ofpisnotdead.com/files/ofpd/islands/Normandy.zip">Normandy</a>'

      expect(repair(html)).to include('files/ofpd/islands/normandy.zip')
    end

    it 'moves a link that still names the host that is gone' do
      html = '<a href="http://ftp.armedassault.info/ofpd/islands/Normandy.zip">Normandy</a>'

      expect(repair(html)).to include('files/ofpd/islands/normandy.zip')
    end

    it 'leaves a path the map does not name' do
      html = '<a href="https://files.ofpisnotdead.com/files/ofpd/islands/other.zip">Other</a>'

      expect(repair(html)).to include('files/ofpd/islands/other.zip')
    end

    context 'when the path it moves to holds a space' do
      let(:moved) { {'ofpd/mods/X.exe' => 'ofpd/mods/Conspiracies Part 1.exe'} }

      it 'escapes it, because the path sits in an attribute' do
        html = '<a href="https://files.ofpisnotdead.com/files/ofpd/mods/X.exe">part one</a>'

        expect(repair(html)).to include('files/ofpd/mods/Conspiracies%20Part%201.exe')
      end
    end
  end

  it 'trims a url that was written with space inside the quotes' do
    html = '<a href="https://files.ofpisnotdead.com/files/ofpd/mods/I44.rar ">x</a>'

    expect(repair(html)).to eq('<a href="https://files.ofpisnotdead.com/files/ofpd/mods/I44.rar">x</a>')
  end

  describe 'a url the old site spliced into itself' do
    it 'keeps the picture path that is buried in it' do
      html = '<img src="/ofpgm/news/pics/b-25/ofpgm/news/pics/b-25/ofpgm/news/pics/' \
             'b-25&#32;yellow&#32;rose.jpg#32;yellow/ofpgm/news/pics/b-25&#32;rose.jpg">'

      expect(repair(html)).to eq('<img src="/ofpgm/news/pics/b-25&#32;yellow&#32;rose.jpg">')
    end

    it 'keeps the first whole url when it is not a picture' do
      html = '<a href="/ofpgm/forum/index.php?showtopic=15561/ofpgm/forum/' \
             'index.php?showtopic=15561">topic</a>'

      expect(repair(html)).to eq('<a href="/ofpgm/forum/index.php?showtopic=15561">topic</a>')
    end

    it 'leaves a url that was never spliced' do
      html = '<img src="../../ofpgm/rest/x.jpg">'

      expect(repair(html)).to eq(html)
    end
  end

  it 'leaves the armedassault website alone' do
    html = '<a href="http://www.armedassault.info/news">news</a>'

    expect(repair(html)).to eq(html)
  end
end

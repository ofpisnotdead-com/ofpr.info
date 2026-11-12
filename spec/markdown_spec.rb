RSpec.describe Ofpr::Markdown do
  def convert(html) = described_class.of(html)

  it 'lifts the screenshot and the download out of an addon card' do
    html = '<center><TABLE BORDER=1><TR><TD ROWSPAN=3>' \
           '<img src="/ofpgm/shots/rpg29.JPG" WIDTH=160><TD WIDTH=100><center>Author' \
           '<TD WIDTH=65><center>Size<br><TR><TD><center><B>Kegetys<TD><center><B>[153 kB]<br>' \
           '<TR><TH COLSPAN=2><a href="https://files.ofpisnotdead.com/files/ofpd/RPG29.zip">' \
           '<img border="0" src="../../ofpgm/images/download.jpg"></a></TABLE></center>'

    expect(convert(html)).to eq(<<~MARKDOWN.strip)
      ![](/ofpgm/shots/rpg29.JPG)

      | Author | Size |
      | --- | --- |
      | **Kegetys** | **[153 kB]** |

      [![](/ofpgm/images/download.jpg)](https://files.ofpisnotdead.com/files/ofpd/RPG29.zip)
    MARKDOWN
  end

  it 'writes a link to the site itself as a path' do
    html = '<a href="../../ofpgm/news/pics/x.jpg">one</a> ' \
           '<a href="http://ofpr.info.paradoxstudio.uk/2679-opflashpoint-it">two</a>'

    expect(convert(html)).to eq('[one](/ofpgm/news/pics/x.jpg) [two](/2679-opflashpoint-it)')
  end

  it 'wraps a url holding a space or a bracket so a reader still sees one url' do
    html = '<a href="https://files.ofpisnotdead.com/files/ofpd/Czerwony Odwet  ( Red ).zip">get</a>'

    expect(convert(html))
      .to eq('[get](<https://files.ofpisnotdead.com/files/ofpd/Czerwony Odwet  ( Red ).zip>)')
  end

  it 'encodes the characters a url may not hold raw' do
    expect(convert('<a href="/<br>http://x.example/">broken</a>'))
      .to eq('[broken](/%3Cbr%3Ehttp://x.example/)')
  end

  it 'keeps the space that was inside the tag outside the marks' do
    expect(convert('The <b>Mod </b>has landed')).to eq('The **Mod** has landed')
  end

  it 'reads the whole of a link text as one line' do
    html = "<a href=\"/x.zip\"><b>DOWNLOAD\n\n(FTP#1) - [2,85 MB]</b></a>"

    expect(convert(html)).to eq('[**DOWNLOAD (FTP#1) - [2,85 MB]**](/x.zip)')
  end

  it 'escapes a number that opens a line, behind a bullet as well' do
    expect(convert('<li>1.  The M93<li>2.  The M14')).to eq("- 1\\. The M93\n- 2\\. The M14")
  end

  it 'points a numbered anchor at the heading it stands in front of' do
    html = '<a href="mods.html#1"><img src="/ofpgm/button.jpg"></a>' \
           '<center><A NAME ="1"></A><img src="/ofpgm/fdf.jpg"></center>' \
           '<h4>Finnish Defence Forces Mod</h4>'

    expect(convert(html)).to start_with('[![](/ofpgm/button.jpg)](mods.html#finnish-defence-forces-mod)')
    expect(convert(html)).to end_with('#### Finnish Defence Forces Mod')
  end

  it 'writes bold inside bold once' do
    expect(convert('<b><a href="http://www.legawarz.com/"><b>Lega Warz Website</b></a></b>'))
      .to eq('**[Lega Warz Website](http://www.legawarz.com/)**')
  end

  it 'keeps a heading as a heading' do
    html = '<h3>Modifications</h3><h4>Finnish <b>Defence</b> Forces</h4>'

    expect(convert(html)).to eq("### Modifications\n\n#### Finnish **Defence** Forces")
  end

  it 'keeps a line break, and reads a blank line as the space html reads it as' do
    html = "<i>-Czech Hedgehog<br>-Logspike with a T-35<br></i> on the <b>BIS\n\nforums</b>"

    expect(convert(html))
      .to eq("*-Czech Hedgehog  \n-Logspike with a T-35*  \non the **BIS forums**")
  end

  it 'leaves a cloaked address inside a mailto link as the label alone' do
    html = '<a href="mailto:x@gmail.com" target="_blank"><b>' \
           '<span id="cloakd0c1">This email address is being protected.</span>' \
           "<script type='text/javascript'>" \
           "document.getElementById('cloakd0c1').innerHTML = '';" \
           "var addyd0c1 = 'x' + '&#64;' + 'gm&#97;&#105;l' + '&#46;' + 'c&#111;m';" \
           "var addy_textd0c1 = 'x&#64;gm&#97;&#105;l&#46;c&#111;m';</script></b></a>"

    expect(convert(html)).to eq('[**x@gmail.com**](mailto:x@gmail.com)')
  end

  it 'runs the script that hid an author address behind a placeholder' do
    html = '<span id="cloakab12">This email address is being protected from spambots.</span>' \
           "<script type='text/javascript'>" \
           "document.getElementById('cloakab12').innerHTML = '';" \
           "var addyab12 = 'sm&#111;k&#101;y' + '&#64;';" \
           "addyab12 = addyab12 + '&#97;&#111;l' + '&#46;' + 'c&#111;m';" \
           "var addy_textab12 = 'M&#97;r&#105;ne';</script>"

    expect(convert(html)).to eq('[Marine](mailto:smokey@aol.com)')
  end

  it 'leaves an embed as the link it amounts to' do
    html = '<object width="425"><param name="movie" value="http://youtube.com/v/abc">' \
           '<embed src="http://youtube.com/v/abc" type="application/x-shockwave-flash"></object>'

    expect(convert(html)).to eq('[http://youtube.com/v/abc](http://youtube.com/v/abc)')
  end

  it 'keeps a form only as the picture of its button' do
    html = '<form action="https://www.paypal.com/cgi-bin/webscr" method="post">' \
           '<input type="hidden" name="cmd" value="_s-xclick">' \
           '<input type="image" src="/ofpgm/news/pics/PayPalDonate.gif" alt="Donate"></form>'

    expect(convert(html)).to eq('![Donate](/ofpgm/news/pics/PayPalDonate.gif)')
  end

  it 'keeps a tag that the article is only talking about' do
    expect(convert('write &lt;b&gt;bold&lt;/b&gt; in a comment'))
      .to eq('write \<b>bold\</b> in a comment')
  end

  it 'indents a list inside a list item instead of starting a second list' do
    html = '<ul><li>files:<ul><li>on a server</li><li>on an ftp</li></ul></li><li>search</li></ul>'

    expect(convert(html)).to eq(<<~MARKDOWN.strip)
      - files:
        - on a server
        - on an ftp
      - search
    MARKDOWN
  end

  it 'keeps a pipe somebody typed out of a table' do
    expect(convert('<p>by <b>FoUs|0|</b></p>')).to eq('by **FoUs\\|0\\|**')
  end

  it 'leaves a ruler drawn under a line as the ruler it was' do
    html = '<p><i>FIXES IN 1.90<br>=============<br>Fixed the thing.</i></p>'

    expect(convert(html)).to eq("*FIXES IN 1.90  \n\\=============  \nFixed the thing.*")
  end

  it 'still reads a rule standing on its own as a rule' do
    expect(convert('<p>one</p><p>---</p><p>two</p>')).to eq("one\n\n---\n\ntwo")
  end

  it 'marks each item of a list an emphasis wraps rather than flatten it' do
    expect(convert('<ul><i><li>one</li><li> two</li></i></ul>')).to eq("- *one*\n- *two*")
  end

  it 'keeps a quote in italics across the list items it runs through, to the end' do
    expect(convert('<i>Said:<br><li>one<li>two<br>and more</i>'))
      .to eq("*Said:*  \n\n- *one*\n- *two*  \n*and more*")
  end

  it 'drops the PayPal tracking pixel beside the donation button' do
    form = '<form action="https://www.paypal.com/cgi-bin/webscr" method="post">' \
           '<input type="image" src="/ofpgm/news/pics/PayPalDonate.gif" alt="Donate">' \
           '<img src="https://www.paypal.com/en_US/i/scr/pixel.gif" width="1" height="1"></form>'

    expect(convert(form)).to eq('![Donate](/ofpgm/news/pics/PayPalDonate.gif)')
  end

  it 'gives up the emphasis marks around a heading as well' do
    expect(convert('<b><h3>Mission I.</h3></b>')).to eq('### Mission I.')
  end
end

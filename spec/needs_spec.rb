require_relative '../lib/ofpr/blocks'

RSpec.describe Ofpr::Needs do
  def needs(markdown) = Ofpr::Blocks.of(markdown).select { |block| block[:type] == 'needs' }

  def names(markdown) = needs(markdown).flat_map { |block| block[:items].map { |item| item[:name] } }

  def files = 'https://files.ofpisnotdead.com/files/ofpd/unofaddons2'

  it 'reads the news form, name and size before a link to the mirror' do
    item = needs("Needed:\nJAM 3 [14,2 MB] from [**FTP#1**](#{files}/JAM3_FIXED6.rar)").first[:items].first

    expect(item).to include(kind: 'file', name: 'JAM 3', size: '14,2 MB', mirror: 1, file: 'JAM3_FIXED6.rar')
  end

  it 'reads packs joined with a plus, and the lines that carry the list on' do
    markdown = "Needed addons: [AK_Hemp [80 KB]](#{files}/AK_Hemp_eng.zip) + " \
               "[Barrack v1.5[3.69 MB]](#{files}/B.zip)\n+ [RKSL-HangersV1 [1,2 MB]](#{files}/RKSL-HangersV1.zip)"

    expect(names(markdown)).to eq(['AK_Hemp', 'Barrack v1.5', 'RKSL-HangersV1'])
  end

  it 'leaves the download written on the line after an inline list as the download' do
    blocks = Ofpr::Blocks.of("Needed addons: [3WX objects](#{files}/F3WX.rar)  \n" \
                             "**[DOWNLOAD (FTP 1) - Nogova 2004 [5,66 MB]](#{files}/Nogova2004v1.rar)**")

    expect(blocks.map { |block| block[:type] }).to eq(%w[needs download])
  end

  it 'reads one pack to a paragraph, and stops where the article turns to its own download' do
    markdown = "Requirements:\n\n1\\. OFP version 1.96\n\n2\\. [BAS Pavehawks v1.1](#{files}/pave.rar)\n\n" \
               "**[DOWNLOAD (FTP#1) - Desert Pavehawk [1,17 MB]](#{files}/demo.zip)**"

    expect(names(markdown)).to eq(['OFP version 1.96', 'BAS Pavehawks v1.1'])
    expect(Ofpr::Blocks.of(markdown).last[:type]).to eq('download')
  end

  it 'reads a list of DOWNLOAD links when the list opened that way' do
    markdown = "**Required addons:**  \n**[DOWNLOAD (mirror #1) - JAM 2 [6 MB]](#{files}/JAM2.rar)**  \n" \
               "**[DOWNLOAD (mirror #1) - BAS OPFOR 1.3 [1 MB]](#{files}/opfor.rar)**"

    expect(names(markdown)).to eq(['JAM 2', 'BAS OPFOR 1.3'])
  end

  it 'reads the marker inside the link, and links to other articles' do
    expect(names("[Need's: Baracken Addon v1.1 [1.65 MB]](#{files}/Baracken1_1.zip)")).to eq(['Baracken Addon v1.1'])
    expect(needs('Needed: [HYK Units](7583-re-textured-hyakushiki.html)').first[:items].first)
      .to include(kind: 'page', url: '/7583-re-textured-hyakushiki.html')
  end

  it 'keeps a name whose link was removed, and leaves prose and a recruiting post alone' do
    removed = "Needed:\nNogovan Light Infantry v.3.4 [25,0 MB] from\nJAM3 [13,5 MB] from [**FTP#1**](#{files}/J.rar)"

    expect(names(removed)).to eq(['Nogovan Light Infantry v.3.4', 'JAM3'])
    expect(needs("We need:\n- modellers\n\nIt requires a lot of work.")).to be_empty
  end

  it 'reads a paragraph per pack after a marker written inside the first link' do
    markdown = "[Need's: Baracken Addon v1.1 [1.65 MB]](#{files}/Baracken1_1.zip)\n\n" \
               "[DOE Winter Everon v1.2 [8.07 MB]](#{files}/Winter_Everon_v1.2.zip)"

    expect(names(markdown)).to eq(['Baracken Addon v1.1', 'DOE Winter Everon v1.2'])
  end

  it 'reads names written with no link, and a link to another site' do
    expect(names("REQUIRED ADDONS:\n\nJAM2\n\nukf_slmg.pbo (from P:UKF's UK pack)"))
      .to eq(['JAM2', "ukf_slmg.pbo (from P:UKF's UK pack)"])
    expect(needs('Needs: **[JAM v2.0](http://www.ofpec.com/addons/JAM.php)**').first[:items].first)
      .to include(kind: 'link', name: 'JAM v2.0')
  end

  it 'ends the list at a row of screenshots and at a change log' do
    markdown = "Needed:\nJAM3 [13,5 MB] from [**FTP#1**](#{files}/J.rar)\n\n" \
               "[![](/ofpgm/a1s.jpg)](/ofpgm/a1.jpg)\n\nNeeded:\nRHS Weap [17 MB] from [**FTP#1**](#{files}/W.rar)\n" \
               "Change log\n- added groups"

    expect(names(markdown)).to eq(['JAM3', 'RHS Weap'])
    expect(Ofpr::Blocks.of(markdown).map { |block| block[:type] }).to eq(%w[needs gallery needs prose])
  end

  it 'names a link labelled with its site by the text in front of it' do
    markdown = "Needed:\nMapfact Barracks [2,7 MB] from [**Mapfact**](http://www.mapfact.net/a)" \
               "\nMAP Heaps V2.0 [229 kB] from [**Mapfact**](http://www.mapfact.net/b)"

    expect(names(markdown)).to eq(['Mapfact Barracks', 'MAP Heaps V2.0'])
  end

  it 'joins a name to its link when the link went onto the next line' do
    markdown = "Needed:\nRHS T-55 pack [9.7 MB] from\n[**FTP#1**](#{files}/RHS_T55Pack_v1.4.rar)"
    item = needs(markdown).first[:items].first

    expect(item).to include(kind: 'file', name: 'RHS T-55 pack', size: '9.7 MB', file: 'RHS_T55Pack_v1.4.rar')
  end

  it 'carries a list on past the separators between its packs, to packs that link an archive page' do
    markdown = "Needed:\n\nCODE BLUE PACK [37 MB] from [**FTP#1**](#{files}/CB_AddOns.rar)\n\n" \
               "![](/ofpgm/images/separator.gif)\n\n" \
               'SEF CH53 PACK [40 MB] from [**FTP#1**](/addons/aircrafts/2166-ch-53-pack.html)'
    items = needs(markdown).first[:items]

    expect(items.map { |item| item[:name] }).to eq(['CODE BLUE PACK', 'SEF CH53 PACK'])
    expect(items.last).to include(kind: 'page', url: '/addons/aircrafts/2166-ch-53-pack.html', size: '40 MB')
  end

  it 'reads a marker with a few words between it and its colon, and tells optional packs apart' do
    expect(names("Needed **only for missions**:\nJAM 2 [5 MB] from [**FTP#1**](#{files}/JAM2.rar)")).to eq(['JAM 2'])
    expect(needs("Optional:\nSFP Swedish Language Units [712 KB] from [**FTP#1**](#{files}/sv.rar)").first[:title])
      .to eq('Optional')
    expect(needs('Needed are : Mission Admins, Newsposters')).to be_empty
  end

  it 'does not take an abbreviation for the end of a sentence' do
    markdown = "Needed:\nRHS Misc. Pack 1.0 [1 MB] from [**FTP#1**](#{files}/RHS_Misc_v1.00.rar)"

    expect(names(markdown)).to eq(['RHS Misc. Pack 1.0'])
  end

  it 'mends a name or a size that a stray line break cut in two' do
    markdown = "Needed:\nRHS T-55 pack v.1.4 [9.7\n\nMB] from [**FTP#1**](#{files}/RHS_T55.rar)\nORCS's\n\n" \
               "Shilka pack [6.3 MB] from [**FTP#1**](#{files}/rus_zsu.rar)"
    items = needs(markdown).first[:items]

    expect(items.map { |item| [item[:name], item[:size]] })
      .to eq([['RHS T-55 pack v.1.4', '9.7 MB'], ["ORCS's Shilka pack", '6.3 MB']])
  end

  it 'ends a list at a ruler, an update note, or a second marker' do
    markdown = "Needed:\nJAM 3 [13 MB] from [**FTP#1**](#{files}/J.rar)\n---\n- Updated RHS GAZ-66 Pack"

    expect(names(markdown)).to eq(['JAM 3'])
    expect(names("Needed:\nA [1 MB] from [**FTP#1**](#{files}/a.rar)\n\n**UPDATE:**\n\nThere is a low res version"))
      .to eq(['A'])
    expect(needs("Needed:\nA [1 MB] from [**FTP#1**](#{files}/a.rar)\n\nNeeded For The Mission:\n" \
                 "B [2 MB] from [**FTP#1**](#{files}/b.rar)").size).to eq(2)
  end

  it 'keeps a second mirror with its pack rather than as a pack of its own' do
    markdown = "Needed:\nFarmland Objects [4.1 MB] from [**FTP#1**](#{files}/Fml.zip) or [FTP#2](#{files}/Fml2.zip)"

    expect(needs(markdown).first[:items])
      .to match([a_hash_including(name: 'Farmland Objects', url: "#{files}/Fml.zip", alt: "#{files}/Fml2.zip")])
  end
end

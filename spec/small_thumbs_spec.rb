require_relative '../lib/ofpr/small_thumbs'

RSpec.describe Ofpr::SmallThumbs do
  before { allow(described_class).to receive(:all).and_return(Set['/ofpgm/m/cw1s.jpg']) }

  it 'grows a listed thumbnail whose full size is a picture' do
    expect(described_class.grown?('thumb' => '/ofpgm/m/cw1s.jpg', 'full' => '/ofpgm/m/cw1.jpg')).to be(true)
    expect(described_class.grown?('thumb' => '/ofpgm/m/cw1s.jpg', 'full' => 'mods.html#cw')).to be(false)
    expect(described_class.grown?('thumb' => '/ofpgm/m/other.jpg', 'full' => '/ofpgm/m/other.jpg')).to be(false)
  end
end

require_relative 'spec_helper'

RSpec.describe Ofpr::Bullets do
  describe '.repair' do
    it 'makes a list of the paragraphs an author drew one with' do
      html = '<p style="padding-left: 30px;">&gt; one</p>' \
             '<p style="padding-left: 30px;">&gt; two</p>'

      expect(described_class.repair(html)).to eq('<ul><li>one</li><li>two</li></ul>')
    end

    it 'nests an item indented further than the one before it' do
      html = '<p style="padding-left: 30px;">&gt; files:</p>' \
             '<p style="padding-left: 60px;">&gt; on a server</p>' \
             '<p style="padding-left: 30px;">&gt; search</p>'

      expect(described_class.repair(html))
        .to eq('<ul><li>files:<ul><li>on a server</li></ul></li><li>search</li></ul>')
    end

    it 'leaves an indented paragraph that is not drawn as a bullet alone' do
      html = '<p style="padding-left: 30px;">a quiet aside</p>'

      expect(described_class.repair(html)).to eq(html)
    end
  end
end

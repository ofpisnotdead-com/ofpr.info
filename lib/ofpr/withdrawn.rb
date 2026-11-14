module Ofpr
  module Withdrawn
    IDS = [9858].freeze
    # A screenshot of the staff page, with each member's face and contact details on it.
    PICTURES = ['/ofpgm/news/pics4/aboutus.jpg'].freeze

    def self.include?(id) = IDS.include?(id.to_i)

    # A picture withheld goes with a link that held nothing else.
    def self.without_pictures(html)
      PICTURES.reduce(html) do |text, path|
        picture = /<img\b[^>]*\bsrc="?#{Regexp.escape(path)}"?[^>]*>/i
        text.gsub(%r{<a\b[^>]*>\s*#{picture.source}\s*</a>}i, '').gsub(picture, '')
      end
    end
  end
end

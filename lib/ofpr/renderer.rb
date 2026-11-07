module Ofpr
  # Stored article html is served as the site wrote it, with the asset paths pointed at
  # the CDN on the way out.
  class Renderer
    # Bodies carry both absolute and relative asset paths: an article two levels deep
    # references `../../ofpgm/x.jpg`, which a browser resolves to the same place. A few
    # were mirrored with the site's own host written in, and that host answers nothing
    # today, so it comes off here and the image loads like any other.
    SITE = 'ofpr\.info\.paradoxstudio\.uk|test\.ofpr\.info'.freeze
    ASSET_REF = %r{(?<attr>(?:src|href)=")(?:https?://(?:#{SITE}))?(?<path>(?:\.\./)*/?ofpgm/(?<tail>[^"]*))"}
    # A browser drops CR and LF from a url; the rebuild's markup carries them inside
    # attribute values, so reading one literally asks for a filename nobody ever had.
    IN_ATTR_BREAK = /[\r\n\t]+/

    def initialize(cdn_base: nil)
      @cdn_base = cdn_base.to_s.delete_suffix('/')
    end

    def call(html)
      html.to_s.gsub(ASSET_REF) do
        match = Regexp.last_match
        %(#{match[:attr]}#{asset_url(match[:tail])}")
      end
    end

    private

    def asset_url(tail)
      tail = tail.gsub(IN_ATTR_BREAK, '')
      @cdn_base.empty? ? "/ofpgm/#{tail}" : "#{@cdn_base}/#{tail}"
    end
  end
end

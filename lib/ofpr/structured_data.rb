require 'json'

require_relative 'prose'

module Ofpr
  # The schema.org Article block the rebuild puts in the head of every article page.
  class StructuredData
    SITE = 'OFP.info 2.5'.freeze
    KEYWORDS = 'ofp, operation, flashpoint, operationflashpoint, arma, cold, war, assault, cwa, ' \
               'coldwarassault, bohemia, interactive, bohemiainteractive, ofpinfo, ofprinfo, ' \
               'ofp.info, ofpr.info, ofp.gamepark.cz'.freeze

    def initialize(article)
      @article = article
    end

    def to_json(*)
      JSON.pretty_generate(
        '@context' => 'https://schema.org',
        '@type' => 'Article',
        'mainEntityOfPage' => {'@type' => 'WebPage', '@id' => url},
        'url' => url,
        'headline' => "#{SITE} - #{Prose.decoded(@article[:title])}",
        'datePublished' => stamp(@article[:published_at]),
        'dateModified' => stamp(@article[:modified_at]),
        'author' => {'@type' => 'Person', 'name' => @article[:author], 'url' => '/'},
        'publisher' => publisher,
        'articleSection' => section,
        'keywords' => KEYWORDS,
        'description' => description,
        'articleBody' => description
      )
    end

    private

    def description = Prose.decoded(@article[:description])

    def url = @article[:url_path]

    def section = @article[:section].to_s.empty? ? '/' : @article[:section]

    def stamp(time) = time&.strftime('%F %T').to_s

    def publisher
      {'@type' => 'Organization', 'name' => SITE, 'url' => '/',
       'logo' => {'@type' => 'ImageObject', 'name' => SITE, 'width' => '', 'height' => '',
                  'url' => '/'}}
    end
  end
end

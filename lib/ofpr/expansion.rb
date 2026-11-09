module Ofpr
  # A debugging view of a listing: every body in full, and as many to a page as asked.
  module Expansion
    def expanded? = params.key?('expand')

    def per_page
      limit = params['limit'].to_i if expanded?
      limit&.positive? ? [limit, Article::MAX_PER_PAGE].min : Article::PER_PAGE
    end

    def listing_base(base)
      limit = "&limit=#{per_page}" unless per_page == Article::PER_PAGE
      expanded? ? "#{base}?expand=1#{limit}" : base
    end
  end
end

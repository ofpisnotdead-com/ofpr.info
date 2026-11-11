module Ofpr
  # A debugging view of a listing: every body in full, and as many to a page as asked.
  # Wide drops the aside, and wide=2 lets the content take the whole window too.
  module Expansion
    def expanded? = params.key?('expand')

    def wide? = params.key?('wide')

    def full_width? = params['wide'] == '2'

    def per_page
      limit = params['limit'].to_i if expanded?
      limit&.positive? ? [limit, Article::MAX_PER_PAGE].min : Article::PER_PAGE
    end

    def listing_base(base)
      query = []
      query << 'expand=1' if expanded?
      query << "limit=#{per_page}" if expanded? && per_page != Article::PER_PAGE
      query << "wide=#{full_width? ? 2 : 1}" if wide?
      query.empty? ? base : "#{base}?#{query.join('&')}"
    end
  end
end

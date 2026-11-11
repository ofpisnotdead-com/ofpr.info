module Ofpr
  # Joomla's com_search parameters, which are part of the url contract, turned into a
  # tsquery and an order clause.
  class SearchQuery
    PHRASES = %w[all any exact].freeze
    ORDERINGS = {
      'newest' => Sequel.desc(:published_at),
      'oldest' => Sequel.asc(:published_at),
      'alpha' => Sequel.asc(:title)
    }.freeze
    LIMITS = [5, 10, 15, 20, 25, 30, 50, 100].freeze
    PER_PAGE = 10

    attr_reader :word, :phrase, :ordering, :start, :per_page

    def initialize(word: nil, phrase: nil, ordering: nil, start: nil, limit: nil)
      @word = word.to_s.strip
      @phrase = PHRASES.include?(phrase) ? phrase : 'all'
      @ordering = ORDERINGS.key?(ordering) ? ordering : 'newest'
      @start = [start.to_i, 0].max
      @per_page = LIMITS.include?(limit.to_i) ? limit.to_i : PER_PAGE
    end

    def blank? = word.empty?

    def terms = word.scan(/[[:alnum:]]+/)

    def tsquery
      return nil if terms.empty?

      case phrase
      when 'exact' then terms.join(' <-> ')
      when 'any' then terms.join(' | ')
      else terms.join(' & ')
      end
    end

    def order = ORDERINGS.fetch(ordering)

    # The pager rounds down to a page boundary, the way Joomla's does.
    def offset = (start / per_page) * per_page
  end
end

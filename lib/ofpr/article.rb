module Ofpr
  module Article
    PER_PAGE = 10

    class << self
      def dataset = Database.connection[:articles]

      def by_url(url_path) = dataset[url_path: url_path]

      # The front page lists the unsectioned items only; a sectioned one is reached
      # through its own listing. The captured pages run from 10673 down to 2479
      # without a gap, which is the whole of this scope.
      def river_scope = dataset.where(section: '')

      def count = river_scope.count

      def total = dataset.count

      # Every section and how much is in it, for the menu and the sidebar, in one query.
      def section_counts
        dataset.exclude(section: '').group_and_count(:section).to_hash(:section, :count)
      end

      def river(start: 0) = newest(river_scope, start)

      # Returns the total alongside the page, because every listing prints it.
      def section(name, start: 0)
        scope = dataset.where(section: name)
        [scope.count, newest(scope, start)]
      end

      def search(query)
        return [0, []] if query.blank?

        scope = dataset.where(condition(query))
        [scope.count,
         scope.order(query.order, Sequel.desc(:id)).limit(query.per_page, query.offset).all]
      end

      private

      # com_search matches a substring, not a stemmed word, so `martin` finds Martins
      # and Aston Martin alike. Reproduced rather than improved on, because the result
      # sets have to be the ones the site showed.
      def condition(query)
        terms = query.phrase == 'exact' ? [query.word] : query.terms
        clauses = terms.map do |term|
          like = "%#{term.gsub(/[\\%_]/) { |c| "\\#{c}" }}%"
          Sequel.|(Sequel.ilike(:title, like), Sequel.ilike(:body_html, like),
            Sequel.ilike(:author, like), Sequel.ilike(:description, like),
            Sequel.ilike(Sequel.function(:coalesce, :cloak_text, ''), like))
        end
        query.phrase == 'any' ? clauses.inject(:|) : clauses.inject(:&)
      end

      # Listings are ordered by the original ids, not by date: the captured pages
      # descend by id with 189 dates out of order among them.
      def newest(scope, start)
        scope.order(Sequel.desc(:id))
          .limit(PER_PAGE, [start.to_i, 0].max / PER_PAGE * PER_PAGE).all
      end
    end
  end
end

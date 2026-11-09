module Ofpr
  module Article
    PER_PAGE = 10
    ID_IN_PATH = %r{(\d+)-[^/]*\z}

    class << self
      def dataset = Database.connection[:articles]

      def by_url(url_path) = dataset[url_path: url_path]

      def by_tail(url_path) = dataset[id: url_path[ID_IN_PATH, 1].to_i]

      # The front page lists the unsectioned items only; a sectioned one is reached
      # through its own listing. The captured pages run from 10673 down to 2479
      # without a gap, which is the whole of this scope.
      def river_scope = dataset.where(section: '')

      def count = river_scope.count

      def total = dataset.count

      # The article each file is the download of, for the files an article needs. An
      # addon's own page wins over the news that announced it.
      def pages_for(urls, besides: nil)
        return {} if urls.empty?

        Database.connection.fetch(<<~SQL, urls).all
          SELECT a.url_path, a.section, a.id, l->>'url' AS url
          FROM articles a, jsonb_array_elements(a.body_blocks) b,
               jsonb_array_elements(coalesce(b->'links', b->'downloads')) l
          WHERE b->>'type' IN ('download', 'card') AND l->>'url' IN ?
        SQL
          .reject { |row| row[:url_path] == besides }
          .sort_by { |row| [row[:section].start_with?('addons/') ? 0 : 1, row[:id]] }
          .each_with_object({}) { |row, pages| pages[row[:url]] ||= row[:url_path] }
      end

      def downloads_at(pages)
        ids = pages.to_h { |page| [page[ID_IN_PATH, 1].to_i, page] }
        return {} if ids.empty?

        Database.connection.fetch(<<~SQL, ids.keys).all
          SELECT a.id, l AS link
          FROM articles a, jsonb_array_elements(a.body_blocks) b,
               jsonb_array_elements(coalesce(b->'links', b->'downloads')) l
          WHERE b->>'type' IN ('download', 'card') AND a.id IN ?
        SQL
          .group_by { |row| row[:id] }
          .filter_map { |id, rows| (link = single_file(rows.map { |row| row[:link] })) && [ids[id], link] }
          .to_h
      end

      def single_file(links)
        links.min_by { |link| link['mirror'].to_i } if links.map { |link| link['file'] }.uniq.one?
      end

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

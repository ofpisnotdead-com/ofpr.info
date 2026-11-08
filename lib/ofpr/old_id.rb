module Ofpr
  module OldId
    FILE = File.expand_path('../../db/old_ids.tsv', __dir__)
    COLUMNS = %i[old_id article_id].freeze

    class << self
      def dataset = Database.connection[:old_ids]

      def [](old_id) = dataset[old_id: old_id.to_i]

      def load!
        rows = pairs
        dataset.delete
        dataset.import(COLUMNS, rows)
        rows.size
      end

      def pairs
        return [] unless File.exist?(FILE)

        File.readlines(FILE, chomp: true).filter_map do |line|
          next if line.start_with?('#') || line.empty?

          old, article = line.split("\t", 2)
          [Integer(old), article.to_s.empty? ? nil : Integer(article)]
        end
      end
    end
  end
end

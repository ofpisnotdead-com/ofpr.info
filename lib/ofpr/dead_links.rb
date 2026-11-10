module Ofpr
  # What the articles still link to and nothing serves, read from `db/dead_links.tsv`:
  # the counts the updates page shows, and the list it offers for download.
  module DeadLinks
    KINDS = {'download' => 'downloads', 'image' => 'pictures', 'page' => 'hosted pages and files'}.freeze
    # From the audit of 2026-11-07 that found these; only an import can move them.
    LINKED = {'download' => 5087, 'image' => 48_093, 'page' => 84}.freeze

    Row = Struct.new(:kind, :path, :links, :article, :title)

    class << self
      def file = File.join(Ofpr.root, 'db', 'dead_links.tsv')

      def all
        @all ||= File.readlines(file, chomp: true)
          .grep_v(/\A#|\A\z/)
          .drop(1)
          .map { |line| Row.new(*line.split("\t")) }
      end

      def count(kind) = all.count { |row| row.kind == kind }

      def linked(kind) = LINKED[kind]
    end
  end
end

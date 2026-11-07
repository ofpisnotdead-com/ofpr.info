require 'sequel'

module Ofpr
  module Database
    DEFAULT_URL = 'postgres://ofpr:ofpr@localhost:5433/ofpr_development'.freeze

    class << self
      def url = ENV.fetch('DATABASE_URL', DEFAULT_URL)

      # Timestamps come from the capture as UTC and are rendered back with a +00:00
      # offset, so nothing may reinterpret them in the importer's own zone.
      def connection
        Sequel.default_timezone = :utc
        @connection ||= Sequel.connect(url)
      end

      def migrate!
        Sequel.extension :migration
        Sequel::Migrator.run(connection, migrations_path)
      end

      def migrations_path = File.expand_path('../../db/migrations', __dir__)
    end
  end
end

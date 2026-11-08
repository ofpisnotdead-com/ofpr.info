module Ofpr
  module SmallThumbs
    FILE = File.expand_path('../../db/small_thumbs.txt', __dir__)
    WIDTH = 100
    PICTURE = /\.(?:jpe?g|png|gif)\z/i

    class << self
      def grown?(shot) = shot['full'].to_s.match?(PICTURE) && all.include?(shot['thumb'])

      def all = @all ||= File.exist?(FILE) ? File.readlines(FILE, chomp: true).to_set : Set.new
    end
  end
end

module Ofpr
  module Withdrawn
    IDS = [9858].freeze

    def self.include?(id) = IDS.include?(id.to_i)
  end
end

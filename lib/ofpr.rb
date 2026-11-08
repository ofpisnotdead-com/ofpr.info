require_relative 'ofpr/database'
require_relative 'ofpr/article'
require_relative 'ofpr/extractor'
require_relative 'ofpr/links'
require_relative 'ofpr/markdown'
require_relative 'ofpr/menu'
require_relative 'ofpr/page'
require_relative 'ofpr/pager'
require_relative 'ofpr/prose'
require_relative 'ofpr/search_query'
require_relative 'ofpr/structured_data'

module Ofpr
  def self.root = File.expand_path('..', __dir__)
end

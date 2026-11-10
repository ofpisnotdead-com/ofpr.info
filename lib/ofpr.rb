require_relative 'ofpr/database'
require_relative 'ofpr/article'
require_relative 'ofpr/bullets'
require_relative 'ofpr/conversion'
require_relative 'ofpr/dead_links'
require_relative 'ofpr/extractor'
require_relative 'ofpr/links'
require_relative 'ofpr/markdown'
require_relative 'ofpr/menu'
require_relative 'ofpr/old_id'
require_relative 'ofpr/page'
require_relative 'ofpr/pager'
require_relative 'ofpr/prose'
require_relative 'ofpr/search_query'
require_relative 'ofpr/small_thumbs'
require_relative 'ofpr/structured_data'
require_relative 'ofpr/withdrawn'

module Ofpr
  def self.root = File.expand_path('..', __dir__)
end

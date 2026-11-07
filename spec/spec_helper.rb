ENV['DATABASE_URL'] ||= 'postgres://ofpr:ofpr@localhost:5433/ofpr_test'
ENV['RACK_ENV'] = 'test'

require 'rack/test'
require_relative '../lib/ofpr'
require_relative '../lib/ofpr/app'

Ofpr::Database.migrate!

# public/ofpgm is a symlink into the mirror in development, and Sinatra serves a static
# file before any route. Routing is what these specs are about, so a developer having
# run assets:link must not change what they see.
Ofpr::App.set(:static, false)

module FixtureHelpers
  def fixture_root = File.expand_path('fixtures/pages', __dir__)

  def fixture_path(name) = File.join(fixture_root, name)

  def insert_article(**attrs)
    row = {id: 1, slug: 'a-thing', url_path: '/1-a-thing', section: '',
           title: 'A thing', body_html: '<p>body</p>',
           published_at: Time.utc(2004, 3, 7)}.merge(attrs)
    Ofpr::Article.dataset.insert(row)
    row
  end

  def insert_page(**attrs)
    row = {url_path: '/mods', title: 'MODS', body_html: '<p>mods</p>'}.merge(attrs)
    Ofpr::Page.dataset.insert(row)
    row
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  config.include FixtureHelpers
  config.include Rack::Test::Methods, type: :request

  config.before { [Ofpr::Article, Ofpr::Page].each { |model| model.dataset.delete } }
end

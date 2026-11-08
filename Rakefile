require 'json'
require 'rack/utils'

MIRROR = ENV.fetch('MIRROR', File.expand_path('../ofp-archive-catalog/ofpr-mirror', __dir__))
SEED = File.expand_path('db/seed.json', __dir__)

def ofpr
  require_relative 'lib/ofpr'
  Ofpr
end

namespace :db do
  desc 'Run migrations'
  task :migrate do
    ofpr::Database.migrate!
    puts "migrated #{ofpr::Database.url}"
  end

  desc 'Drop every table and migrate again'
  task :reset do
    db = ofpr::Database.connection
    db.tables.each { |t| db.drop_table?(t, cascade: true) }
    ofpr::Database.migrate!
    puts 'reset'
  end

  desc 'Load db/seed.json'
  task :seed do
    seed = JSON.parse(File.read(SEED), symbolize_names: true)
    [[ofpr::Article.dataset, seed.fetch(:articles)],
     [ofpr::Page.dataset, seed.fetch(:pages)]].each do |table, rows|
      table.delete
      rows.each { |row| table.insert(insertable(row)) }
    end
    puts "seeded #{seed[:articles].size} articles and #{seed[:pages].size} pages"
  end
end

namespace :mirror do
  desc 'Import every article page from the mirror (MIRROR=path)'
  task :import do
    table = ofpr::Article.dataset
    table.delete
    ok = failed = 0
    article_pages(MIRROR).each do |path|
      row = extract(path)
      row ? (table.insert(insertable(row)) and ok += 1) : failed += 1
    end
    featured = mark_featured(table)
    pages = import_menu_pages
    puts "imported #{ok} articles, #{failed} unusable, #{featured} featured, #{pages} menu pages"
  end

  desc 'Rebuild db/seed.json from the mirror'
  task :seed do
    seed = {articles: sample(article_pages(MIRROR)).filter_map { |path| extract(path) },
            pages: menu_page_files.map { |path| ofpr::Extractor.menu_page(path, root: MIRROR).to_h }}
    File.write(SEED, "#{JSON.pretty_generate(seed)}\n")
    puts "wrote #{seed[:articles].size} articles and #{seed[:pages].size} pages to #{SEED}"
  end
end

namespace :assets do
  # The layout ships with the app in public/. Only the article images are the CDN's, and
  # in development they come from the mirror through this symlink.
  desc 'Link the mirror article images into public/ofpgm (MIRROR=path)'
  task :link do
    target = File.join(MIRROR, 'ofpgm')
    link = File.expand_path('public/ofpgm', __dir__)
    abort "no ofpgm in #{MIRROR}" unless File.directory?(target)

    FileUtils.rm_rf(link)
    FileUtils.ln_s(target, link)
    puts "linked public/ofpgm -> #{target}"
  end
end

# The verification renders the markdown back to html to compare the two, which the
# app itself has no reason to do, so it is loaded here rather than with the rest.
def port
  require_relative 'lib/ofpr/port'
  ofpr::Port
end

namespace :port do
  desc 'Convert every body to markdown and report what the conversion lost'
  task :verify do
    columns = %i[url_path body_html body_markdown body_blocks]
    bodies = ofpr::Article.dataset.select(*columns).order(:id).all +
             ofpr::Page.dataset.select(*columns).order(:url_path).all
    faults = bodies.filter_map do |row|
      complaints = port.check(row[:body_html], stored: row[:body_markdown],
        stored_blocks: row[:body_blocks])
      [row[:url_path], complaints] unless complaints.empty?
    end
    faults.each { |path, complaints| puts "  #{path}: #{complaints.join('; ')}" }
    puts "#{bodies.size - faults.size} of #{bodies.size} bodies ported with nothing lost"
    abort "#{faults.size} bodies lost something" unless faults.empty?
  end

  desc 'Print one body as markdown (URL=/path)'
  task :show do
    path = ENV.fetch('URL')
    row = ofpr::Article.by_url(path) || ofpr::Page.dataset[url_path: path]
    abort "no body at #{path}" unless row

    puts ofpr::Markdown.of(row[:body_html])
    complaints = port.check(row[:body_html])
    warn "\n#{complaints.join("\n")}" unless complaints.empty?
  end
end

desc 'Request every local url a running app links to and report the broken ones'
task :links do
  require 'json'
  require 'net/http'
  base = URI(ENV.fetch('BASE', 'http://127.0.0.1:9292'))
  seed = JSON.parse(File.read(SEED))
  pages = ['/', '/?start=10'] +
          seed.values_at('articles', 'pages').flatten.map { |row| row['url_path'] }
  known = ofpr::Article.dataset.select_map(:url_path).to_set
  known.merge(ofpr::Page.dataset.select_map(:url_path))
  known.merge(ofpr::Article.section_counts.keys.map { |section| "/#{section}" })
  broken = {}
  checked = inherited = 0
  Net::HTTP.start(base.host, base.port) do |http|
    pages.each do |page|
      body = http.get(page == '/' ? page : "#{page}.html").body.to_s
      body.scan(%r{(?:src|href)="(/[^"]*)"}).flatten.uniq.each do |url|
        next if url == '/'

        url = url.gsub('&amp;', '&')
        checked += 1
        code = http.head(url).code
        next if code.start_with?('2', '3')

        ours?(url, known) ? broken[url] = code : inherited += 1
      end
    end
  end
  puts "#{pages.size} pages, #{checked} links, #{broken.size} broken, " \
       "#{inherited} that an article wrote to a page the site never had"
  broken.sort.each { |url, code| puts "  #{code} #{url}" }
  abort "#{broken.size} broken links" unless broken.empty?
end

# A link a template makes has to resolve. A link an article's own text makes is
# whatever its author typed in 2003 - an email with no mailto, a domain with no scheme -
# and three of the site's own paths were never captured either: its forum, its author
# pages, and the cookie plugin's stylesheets, which the live site 404s as well.
NEVER_CAPTURED = %r{\A/(ofpgm/forum/|plugins/system/fmalertcookies/|author/)}

def ours?(url, known)
  return false if url.match?(NEVER_CAPTURED)

  path = url.split('#').first.split('?').first.to_s.delete_suffix('.html')
  known.include?(path) || path.start_with?('/assets/', '/images/', '/ofpgm/', '/archive')
end

desc 'Check every captured listing against what the data lists (MIRROR=path)'
task :compare do
  same = differ = unusable = 0
  listing_captures.each do |file, url|
    capture = File.read(File.join(MIRROR, file), encoding: 'UTF-8')
    # A capture that lost its closing tag was truncated in transit and lists nothing.
    next unusable += 1 unless capture.include?('</html>')

    want = listed_in(capture).map(&:to_i)
    next unusable += 1 if want.empty?

    got = listed_by_data(url)
    # A listing that fits on one page carries no pager and so no count to compare.
    said = capture[/<li class="counter">Page \d+ of (\d+)/, 1]&.to_i
    pages = [said, said && page_count(url)]
    if want == got && pages.uniq.size == 1
      same += 1
    else
      differ += 1
      puts "  differs: #{url}"
      puts "    capture lists #{want.inspect}" unless want == got
      puts "    data lists    #{got.inspect}" unless want == got
      puts "    capture says #{said} pages, the data has #{pages.last}" if pages.uniq.size > 1
    end
  end
  puts "#{same} listings hold what the data holds, #{differ} differ, " \
       "#{unusable} captures list nothing"
  abort "#{differ} listings differ" unless differ.zero?
end

desc 'Check the captures still match what test.ofpr.info serves (N=pages, DELAY=secs)'
task :verify_captures do
  require 'digest'
  require 'net/http'
  require 'uri'
  live = URI('https://test.ofpr.info')
  delay = Float(ENV.fetch('DELAY', '4'))
  same = differ = unserved = 0
  # The live host serves static files and ignores a query string, so a capture whose
  # filename holds one cannot be addressed there: it answers with page one instead.
  addressable = capture_pages(Integer(ENV.fetch('N', '20')))
    .map(&:first).reject { |name| name.include?('?') }
  addressable.each do |file|
    sleep delay
    body = fetch_live(live, "/#{file}")
    next unserved += 1 unless body

    want = Digest::MD5.hexdigest(File.binread(File.join(MIRROR, file)))
    if want == Digest::MD5.hexdigest(body)
      same += 1
    else
      differ += 1
      puts "  differs: /#{file}"
    end
  end
  puts "#{same} byte-identical to the live site, #{differ} differ, #{unserved} not served, " \
       "of #{addressable.size} the host can address"
  abort "#{differ} captures no longer match the live site" unless differ.zero?
end

desc 'Run the specs'
task :test do
  sh 'rspec'
end

desc 'Run the linter'
task :lint do
  sh 'rubocop'
end

desc 'Lint and test'
task check: %i[lint test]

task default: :check

# Every <id>-<slug>.html below the capture root, at any depth: the river sits at the
# root and the addon and mission databases sit under their sections.
def article_pages(root)
  Dir.glob("#{root}/**/[0-9]*-*.html").reject { |p| p.include?('/_source/') }.sort
end

# A seed has to cover the river and every section, so take a spread from each directory.
# The river gets more because it is the only listing worth paging through.
def sample(paths)
  paths.group_by { |p| File.dirname(p) }
    .flat_map { |dir, group| spread(group, dir == MIRROR ? 30 : 3) }
end

def spread(paths, take)
  return paths if paths.size <= take

  paths.each_slice(paths.size / take).map(&:first).first(take)
end

# Every captured page that lists articles, paired with the url it was served at: the
# river and its pages, each section and its pages, and the searches.
def listing_captures
  files = Dir.glob("#{MIRROR}/index.html*") +
          Dir.glob("#{MIRROR}/{addons,missions}/*.html") +
          Dir.glob("#{MIRROR}/{patches,utilities}.html*") +
          Dir.glob("#{MIRROR}/search.html?*.html")
  files.sort.map { |path| path.delete_prefix("#{MIRROR}/") }
    .grep_v(ARTICLE_FILE)
    .map { |file| [file, capture_url(file)] }
end

ARTICLE_FILE = %r{(\A|/)\d+-}

# What a captured listing lists: the ids live in the hrefs, and one article has an
# empty slug, so the capture links it as `3532-.html`.
LIST_START = ['<div class="itemList">', '<dl class="search-results">'].freeze
ITEM_SPLIT = /class="itemContainer|<dt class="result-title">/
ITEM_ID = /href="[^"]*?(\d{3,5})-[a-z0-9-]*(?:\.html)?"/
PAGER_START = '<nav class="pagination">'.freeze

def listed_in(html)
  at = LIST_START.filter_map { |marker| html.index(marker) }.min
  return [] unless at

  region = html[at...(html.index(PAGER_START, at) || html.length)]
  region.split(ITEM_SPLIT)[1..].to_a.filter_map { |item| item[ITEM_ID, 1] }
end

# What the data puts on that page, as ids in order. This is the whole of the check:
# the markup is ours now, the ids and their order are the archive's.
def listed_by_data(url)
  path, _, query = url.partition('?')
  start = query[/start=(\d+)/, 1].to_i
  rows = case path
         when '/' then ofpr::Article.river(start: start)
         when %r{\A/search} then ofpr::Article.search(query_from(query)).last
         else ofpr::Article.section(path.delete_prefix('/'), start: start).last
         end
  rows.map { |row| row[:id] }
end

def page_count(url)
  path, _, query = url.partition('?')
  per = path.start_with?('/search') ? ofpr::SearchQuery::PER_PAGE : ofpr::Article::PER_PAGE
  total = case path
          when '/' then ofpr::Article.count
          when %r{\A/search} then ofpr::Article.search(query_from(query)).first
          else ofpr::Article.section(path.delete_prefix('/')).first
          end
  [(total.to_f / per).ceil, 1].max
end

def query_from(query)
  params = Rack::Utils.parse_query(query)
  ofpr::SearchQuery.new(word: params['searchword'], phrase: params['searchphrase'],
    ordering: params['ordering'], start: params['start'])
end

# Captured pages paired with the url the app serves them at, spread across every page
# type: the river and its pages, articles at each depth, section listings and searches.
def capture_pages(limit)
  listings = Dir.glob("#{MIRROR}/index.html?start=*.html")
  sections = Dir.glob("#{MIRROR}/{addons,missions}/*.html").grep_v(/\?/).sort
  articles = article_pages(MIRROR)
  searches = Dir.glob("#{MIRROR}/search.html?*.html")
  per = [limit / 4, 1].max
  picked = listings.first(per) + sections.first(per) + spread(articles, per) +
           searches.first(per) + menu_pages
  (['index.html', 'index.php.html'] + picked.map { |path| path.delete_prefix("#{MIRROR}/") })
    .uniq.map { |file| [file, capture_url(file)] }
end

# The menu points at one page that is a K2 item rather than a listing.
def menu_page_files
  Dir.glob("#{MIRROR}/*.html").grep_v(/\?/).reject { |path| File.basename(path) =~ /\A\d/ }
    .select { |path| File.read(path, encoding: 'UTF-8').include?('class="itemView"') }.sort
end

def import_menu_pages
  table = ofpr::Page.dataset
  table.delete
  menu_page_files.each do |path|
    table.insert(insertable(ofpr::Extractor.menu_page(path, root: MIRROR).to_h))
  end
  table.count
end

# The pages the top menu points at, which are neither the river nor a section listing.
def menu_pages
  Dir.glob("#{MIRROR}/{mods,patches,utilities,search}.html") +
    Dir.glob("#{MIRROR}/{patches,utilities}.html?start=*.html")
end

# wget rewrote the query into the filename and appended .html, so the url has to be put
# back together: drop that suffix, split off the query, then drop .html from the path.
def capture_url(file)
  rest = file.delete_suffix('.html')
  path, _, query = rest.partition('?')
  path = path.delete_suffix('.html').delete_suffix('/index')
  path = '' if path == 'index'
  query.empty? ? "/#{path}" : "/#{path}?#{query}"
end

# K2 marks a few items featured, and only the listing captures say which.
def mark_featured(table)
  ids = Dir.glob("#{MIRROR}/{index.html*,addons/*.html,missions/*.html}").flat_map do |path|
    File.read(path, encoding: 'UTF-8').scan(/itemIsFeatured.*?<a href="[^"]*?(\d+)-/m).flatten
  end.uniq.map(&:to_i)
  table.where(id: ids).update(featured: true)
end

# One request at a time, spaced, with a user agent naming the crawl: the live site is
# the reference of record but it is also somebody's server.
def fetch_live(live, path)
  uri = URI.join(live.to_s, path)
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = 'Mozilla/5.0 (compatible; ofp-archive/1.0; layout comparison)'
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15,
    read_timeout: 30) { |http| http.request(request) }
  response.is_a?(Net::HTTPSuccess) ? response.body.to_s : nil
rescue StandardError => e
  warn "  #{path}: #{e.class}"
  nil
end

# The blocks are a structure in a row and json text in the column, and the seed file
# keeps them as json so a rule change shows up there as something a person can read.
def insertable(row)
  row.key?(:body_blocks) ? row.merge(body_blocks: JSON.generate(row[:body_blocks])) : row
end

def extract(path)
  row = ofpr::Extractor.call(path, root: MIRROR).to_h
  row[:published_at] = row[:published_at]&.iso8601
  row[:modified_at] = row[:modified_at]&.iso8601
  row
rescue ofpr::Extractor::Invalid
  nil
end

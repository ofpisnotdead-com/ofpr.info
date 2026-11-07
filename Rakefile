require 'json'

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
      rows.each { |row| table.insert(row) }
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
      row ? (table.insert(row) and ok += 1) : failed += 1
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
  # The capture saved Joomla's cache-busted assets with the query string baked into the
  # filename, so `core.js?2b52...` sits on disk where a browser asks for `core.js`. The
  # capture also saved the site's catch-all page under some of those names, so a
  # candidate whose first bytes are html is never the asset.
  desc 'Give the captured assets the names a browser asks for'
  task :normalise do
    renamed = dropped = 0
    Dir.glob('public/{media,templates}/**/*').select { |f| File.file?(f) }.sort.each do |path|
      clean = path.delete_suffix('.html').sub(%r{\?[^/]*\z}, '')
      clean += File.extname(clean.sub(/\.[^.]*\z/, '')) if File.extname(clean).empty?
      next if clean == path

      if html?(path) || (File.exist?(clean) && !html?(clean))
        FileUtils.rm_f(path)
        dropped += 1
      else
        FileUtils.mv(path, clean)
        renamed += 1
      end
    end
    rewritten = rewrite_css_urls
    puts "renamed #{renamed}, dropped #{dropped}, #{rewritten} stylesheets repointed"
  end

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

desc 'Request every local url a running app links to and report the broken ones'
task :links do
  require 'json'
  require 'net/http'
  base = URI(ENV.fetch('BASE', 'http://127.0.0.1:9292'))
  seed = JSON.parse(File.read(SEED))
  pages = ['/', '/?start=10'] +
          seed.values_at('articles', 'pages').flatten.map { |row| row['url_path'] }
  broken = {}
  checked = 0
  Net::HTTP.start(base.host, base.port) do |http|
    pages.each do |page|
      body = http.get(page).body.to_s
      body.scan(%r{(?:src|href)="(/[^"]*)"}).flatten.uniq.each do |url|
        next if url == '/'

        url = url.gsub('&amp;', '&')
        checked += 1
        code = http.head(url).code
        broken[url] = code unless code.start_with?('2', '3')
      end
    end
  end
  puts "#{pages.size} pages, #{checked} links, #{broken.size} broken"
  broken.sort.each { |url, code| puts "  #{code} #{url}" }
  # Three of these the original 404s as well: its own long-gone forum, the cookie
  # plugin's stylesheets, which test.ofpr.info also answers 404 for, and the one author
  # page, which the capture never held.
  expected = %r{\A/(ofpgm/forum/|plugins/system/fmalertcookies/|author/)}
  unexpected = broken.keys.grep_v(expected)
  abort "#{unexpected.size} broken links" unless unexpected.empty?
end

desc 'Compare rendered pages against the captured ones (MIRROR=path, BASE=url, N=pages)'
task :compare do
  require 'net/http'
  base = URI(ENV.fetch('BASE', 'http://127.0.0.1:9292'))
  pages = capture_pages(Integer(ENV.fetch('N', '200')))
  same = differ = 0
  partial = whole = truncated = 0
  consent = false
  Net::HTTP.start(base.host, base.port) do |http|
    consent = http.get('/').body.to_s.include?('fmalertcookies')
    pages.each do |file, path|
      capture = File.read(File.join(MIRROR, file), encoding: 'UTF-8')
      capture = ofpr::Skeleton.without_consent(capture) unless consent
      # A capture that lost its head or its closing tag was truncated in transit and
      # describes no complete page.
      next truncated += 1 unless capture.include?('<head>') && capture.include?('</html>')

      rendered = http.get(path).body.to_s
      if ofpr::Skeleton.degraded_pager?(capture)
        partial += 1
        want = [ofpr::Skeleton.of_without_numbers(capture), ofpr::Skeleton.pager_frame(capture)]
        got = [ofpr::Skeleton.of_without_numbers(rendered), ofpr::Skeleton.pager_frame(rendered)]
      else
        whole += 1 if capture.include?(ofpr::Skeleton::PAGER_START)
        want = [ofpr::Skeleton.of(capture), ofpr::Skeleton.pager_frame(capture)]
        got = [ofpr::Skeleton.of(rendered), ofpr::Skeleton.pager_frame(rendered)]
      end
      want << ofpr::Skeleton.listed_ids(capture)
      got << ofpr::Skeleton.listed_ids(rendered)
      if want == got
        same += 1
      else
        differ += 1
        puts "  differs: #{path}  (capture #{want.first.size} tags, app #{got.first.size})"
        want.zip(got).each do |mine, theirs|
          puts "    only in capture: #{(mine - theirs).tally.first(4).inspect}" unless (mine - theirs).empty?
          puts "    only in app:     #{(theirs - mine).tally.first(4).inspect}" unless (theirs - mine).empty?
        end
      end
    end
  end
  puts "#{same} identical, #{differ} differ, of #{pages.size - truncated} comparable " \
       "(#{whole} pagers compared in full, #{partial} without the numbers the mirror " \
       "lost, #{truncated} truncated captures skipped)"
  puts '  the app has the cookie notice off, so the capture was compared without it' unless consent
  abort "#{differ} pages differ" unless differ.zero?
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
  menu_page_files.each { |path| table.insert(ofpr::Extractor.menu_page(path, root: MIRROR).to_h) }
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

# wget escaped the query inside stylesheets too, so font-awesome asks for
# `fontawesome-webfont.woff2%3Fv=4.4.0` as a literal path and the icons never load.
def rewrite_css_urls
  Dir.glob('public/{media,templates}/**/*.css').count do |path|
    before = File.read(path, encoding: 'UTF-8')
    after = before.gsub(/%3F/i, '?')
    next false if after == before

    File.write(path, after)
    true
  end
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

def html?(path)
  File.binread(path, 40).to_s.match?(/\A\s*<(!doctype html|html)/i)
end

def extract(path)
  row = ofpr::Extractor.call(path, root: MIRROR).to_h
  row[:published_at] = row[:published_at]&.iso8601
  row[:modified_at] = row[:modified_at]&.iso8601
  row
rescue ofpr::Extractor::Invalid
  nil
end

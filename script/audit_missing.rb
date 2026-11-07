#!/usr/bin/env ruby
# What the articles ask for that the archive does not hold.
#
#   ruby script/audit_missing.rb [out-dir] [status-dir]
#
# Writes `missing.csv`: one row per referenced path that is not on disk, with the type,
# how many articles want it, one of them as an example, and what the host said.
#
# The host columns are filled from `status-dir`, which holds tab separated `path<TAB>code`
# files written by whatever checked them: `downloads.tsv`, `images.tsv`, `pages.tsv`.
# Without them the column reads `not checked`, because this script asks no host itself.

require 'cgi'
require 'fileutils'
require_relative '../lib/ofpr'

ARCHIVE = ENV.fetch('ARCHIVE', File.expand_path('../../ofp-archive-catalog/archive', __dir__))
MIRROR = ENV.fetch('MIRROR', File.expand_path('../../ofp-archive-catalog/ofpr-mirror', __dir__))
OUT = ARGV[0] || File.expand_path('../../ofp-archive-catalog/gen-docs/ofpr-missing', __dir__)
STATUS = ARGV[1]

DOWNLOAD = %r{(?:href|src)="https://files\.ofpisnotdead\.com/files/([^"]+)"}i
IMAGE = %r{(?:src|href)="((?:\.\./)*/?ofpgm/[^"]+\.(?:jpe?g|png|gif|bmp))"}i
PAGE = %r{href="((?:\.\./)*/?ofpgm/[^"]+\.(?:html?|php|txt|zip|rar|exe))"}i
KINDS = {download: DOWNLOAD, image: IMAGE, page: PAGE}.freeze
FIELDS = %i[type path references example_article example_title in_local_archive on_host
            note].freeze

# An attribute value is html before it is a url: `&#32;` is the space in a file name.
def clean(path)
  text = CGI.unescapeHTML(path.to_s.split('?').first.to_s.gsub(/[\r\n\t]/, ''))
  text.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr }.strip
end

def statuses(name)
  file = STATUS && File.join(STATUS, "#{name}.tsv")
  return {} unless file && File.exist?(file)

  File.readlines(file, chomp: true).to_h { |line| line.split("\t", 2) }
end

def collect
  found = KINDS.keys.to_h { |kind| [kind, Hash.new { |h, k| h[k] = [] }] }
  Ofpr::Article.dataset.select(:id, :url_path, :title, :body_html).each do |row|
    where = [row[:url_path], CGI.unescapeHTML(row[:title].to_s)]
    KINDS.each do |kind, pattern|
      row[:body_html].to_s.scan(pattern) do |(path)|
        found[kind][clean(path).sub(%r{\A(?:\.\./)*/?ofpgm/}, '')] << where
      end
    end
  end
  found
end

def held?(kind, path)
  kind == :download ? File.file?(File.join(ARCHIVE, path)) : File.file?(File.join(MIRROR, 'ofpgm', path))
end

def note_for(kind, path, code)
  return 'the videos folder was never archived' if path.start_with?('ofpd/videos/')
  return 'the site itself filed it under missingpics' if path.start_with?('missingpics/')
  return 'answers on the host, absent from the local archive copy' if code == '200'
  return 'not checked against the host' if code.nil?

  kind == :download ? 'not in the archive and not on the host' : 'gone from the live site too'
end

def field(value)
  text = value.to_s
  text.match?(/[",\n]/) ? %("#{text.gsub('"', '""')}") : text
end

codes = {download: statuses('downloads'), image: statuses('images'), page: statuses('pages')}
rows = collect.flat_map do |kind, paths|
  paths.reject { |path, _| held?(kind, path) }.map do |path, places|
    code = codes[kind][path]
    {type: kind.to_s, path: path, references: places.size,
     example_article: places.first[0], example_title: places.first[1],
     in_local_archive: 'no', on_host: code || 'not checked',
     note: note_for(kind, path, code)}
  end
end
rows.sort_by! { |row| [row[:type], row[:path].downcase] }

FileUtils.mkdir_p(OUT)
File.open(File.join(OUT, 'missing.csv'), 'w') do |file|
  file.puts FIELDS.join(',')
  rows.each { |row| file.puts FIELDS.map { |key| field(row[key]) }.join(',') }
end

puts "wrote #{rows.size} rows to #{File.join(OUT, 'missing.csv')}"
rows.group_by { |row| row[:type] }.each do |type, list|
  counts = {type: type, missing: list.size,
            refs: list.sum { |row| row[:references] },
            serving: list.count { |row| row[:on_host] == '200' }}
  puts format('  %<type>-9s %<missing>4d missing, %<refs>5d references, ' \
              '%<serving>d still answer on the host', counts)
end

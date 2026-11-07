require 'cgi'

module Ofpr
  # The download host the articles were written against, ftp.armedassault.info, is gone.
  # Every file it served is on files.ofpisnotdead.com under `files` plus the same path,
  # which is how the articles that link to both already write it. Most do link to both,
  # the second time as an "FTP#2" pointer beside the first, so moving the dead url over
  # would leave two links on one file: the pointer goes and the link that carries the
  # wording stays. What survives is written to https, which the host answers and the
  # articles did not, and pointed at the path the file is really served from.
  module Links
    DEAD = %r{https?://ftp\.armedassault\.info/}i
    INSECURE = %r{http://files\.ofpisnotdead\.com/}i
    LIVE = 'https://files.ofpisnotdead.com/files/'.freeze
    SECURE = 'https://files.ofpisnotdead.com/'.freeze
    LIVE_URL = %r{https://files\.ofpisnotdead\.com/}i

    ANCHOR = %r{<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>}mi
    # A link that only says which mirror it is: FTP#2, (from mirror #2), and the like.
    POINTER = /\b(?:ftp|mirror)\s*#?\s*\d\b/i
    # Often it says so with a button rather than words, and the mirror is in the file
    # name: downloadftp1.jpg beside downloadftp2.jpg on the same download.
    IMAGE = /<img[^>]*\ssrc="([^"]*)"/i
    POINTER_IMAGE = /(?:ftp|mirror)[_-]?\s*#?\s*\d/i
    EMPTY_WRAPPER = %r{<(small|center|b)>\s*</\1>}i
    EMPTY_SMALL = %r{(?:&nbsp;|\s)*<small>\s*</small>}i
    # "from <a>FTP#1</a> or <a>FTP#2</a>" can lose both of its links to another block.
    DANGLING_OR = %r{\s+or\b\s*(?=</)}i

    # Some links name a path the file is not at, most often because the article wrote
    # the name in a different case than the archive stores it. Where the file is in the
    # archive under another path, the link is pointed at the path it is really served
    # from. Each pair here was confirmed to answer on the host before it was written
    # down; `db/moved_downloads.tsv` holds them.
    MOVED_FILE = File.expand_path('../../db/moved_downloads.tsv', __dir__)
    LINKED_PATH = /(#{Regexp.escape(LIVE)})([^"'\s>]+)/

    class << self
      def repair(html)
        text = html.to_s.gsub(DEAD, LIVE).gsub(INSECURE, SECURE)
        drop_duplicate_pointers(move(text))
      end

      def moved
        @moved ||= File.exist?(MOVED_FILE) ? read_moved : {}
      end

      private

      def read_moved
        File.readlines(MOVED_FILE, chomp: true).filter_map do |line|
          from, to = line.split("\t", 2)
          [from, to] if to && !from.start_with?('#')
        end.to_h
      end

      # The path sits in an attribute, so a space in it is written as an escape.
      def move(html)
        return html if moved.empty?

        html.gsub(LINKED_PATH) do
          host = Regexp.last_match(1)
          path = Regexp.last_match(2)
          found = moved[decode(path)]
          found ? "#{host}#{found.gsub(' ', '%20')}" : "#{host}#{path}"
        end
      end

      def decode(path)
        text = CGI.unescapeHTML(path.split('?').first.to_s)
        text.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr }
      end

      # Only an anchor whose own words are a mirror pointer is dropped, and only when the
      # file it points at is already linked somewhere else in the same article.
      def drop_duplicate_pointers(html)
        seen, worded = census(html)
        return html if seen.values.none? { |n| n > 1 }

        kept = Hash.new(0)
        tidy(html.gsub(ANCHOR) { survivor(Regexp.last_match, seen, worded, kept) })
      end

      # How many links each file has, and how many of those say more than which mirror.
      def census(html)
        seen = Hash.new(0)
        worded = Hash.new(0)
        html.scan(ANCHOR) do |href, label|
          next unless href.match?(LIVE_URL)

          seen[href] += 1
          worded[href] += 1 unless pointer?(label)
        end
        [seen, worded]
      end

      # A file never loses every link: where nothing but pointers link it, the first of
      # them stays, which is the one the page leads with.
      def survivor(match, seen, worded, kept)
        href = match[1]
        return match[0] unless seen[href] > 1 && pointer?(match[2])

        kept[href] += 1
        worded[href].zero? && kept[href] == 1 ? match[0] : ''
      end

      def pointer?(label)
        source = label[IMAGE, 1]
        return true if source&.match?(POINTER_IMAGE)

        words = label.gsub(/<[^>]*>/, '').gsub(/&nbsp;/i, ' ').strip
        !words.empty? && words.match?(POINTER)
      end

      # Removing an anchor leaves the small tag, separator or centred line that framed
      # it, and emptying one wrapper can empty the one around it.
      def tidy(html)
        4.times do
          tidied = html.gsub(EMPTY_SMALL, '').gsub(EMPTY_WRAPPER, '').gsub(DANGLING_OR, '')
          break if tidied == html

          html = tidied
        end
        html
      end
    end
  end
end

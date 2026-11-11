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

    ANCHOR = %r{<a\s[^>]*href=(?:"([^"]*)"|([^\s>"]+))[^>]*>(.*?)</a>}mi
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

    # A few pages carry a url that a bad search and replace on the old site turned
    # inside out: the path is spliced into itself at every space, leaving thousands of
    # characters where one file name belongs. The whole url is still in there, as the
    # first run that reaches a picture's extension without starting over, or for a link
    # that is not a picture, as everything before the path begins again.
    # A url written with space around it inside the quotes. A browser trims that before
    # asking for it; a lookup against the archive does not, so it is trimmed here.
    PADDED = /((?:src|href)=")([^"]*)(")/i
    MANGLED = %r{((?:src|href)=")([^"]*/ofpgm/[^"]*/ofpgm/[^"]*)(")}i
    PICTURE = %r{/ofpgm/(?:(?!/ofpgm/)[^"])*?\.(?:jpe?g|png|gif|bmp)}i
    FIRST_RUN = %r{\A[^"]*?/ofpgm/(?:(?!/ofpgm/)[^"])*}i

    # Some links name a path the file is not at, most often because the article wrote
    # the name in a different case than the archive stores it. Where the file is in the
    # archive under another path, the link is pointed at the path it is really served
    # from. Each pair here was confirmed to answer on the host before it was written
    # down; `db/moved_downloads.tsv` holds them.
    MOVED_FILE = File.expand_path('../../db/moved_downloads.tsv', __dir__)
    # The path runs to the closing quote: plenty of these file names hold spaces.
    LINKED_PATH = /((?:src|href)="#{Regexp.escape(LIVE)})([^"]*)(")/i

    # Links to a host that is gone, and what serves the same thing now: a copy on our
    # host, one recovered from the Wayback Machine, or the video put up elsewhere.
    # `db/replaced_links.tsv` holds them. A url broken over lines still counts as one.
    REPLACED_FILE = File.expand_path('../../db/replaced_links.tsv', __dir__)
    ATTRIBUTE = /\b(src|href)=(?:"([^"]*)"|([^\s>"]+))/i

    class << self
      def repair(html)
        text = replace(unmangle(trim(html.to_s))).gsub(DEAD, LIVE).gsub(INSECURE, SECURE)
        drop_duplicate_pointers(move(text))
      end

      # The match is taken whole first: reading the url with another pattern would
      # replace the match data the closing quote is still in.
      def trim(html)
        html.gsub(PADDED) do
          match = Regexp.last_match
          "#{match[1]}#{match[2].strip}#{match[3]}"
        end
      end

      def unmangle(html)
        html.gsub(MANGLED) do
          match = Regexp.last_match
          url = match[2]
          "#{match[1]}#{url[PICTURE] || url[FIRST_RUN] || url}#{match[3]}"
        end
      end

      def moved
        @moved ||= read_pairs(MOVED_FILE)
      end

      def replaced
        @replaced ||= read_pairs(REPLACED_FILE)
      end

      private

      def read_pairs(file)
        return {} unless File.exist?(file)

        File.readlines(file, chomp: true).filter_map do |line|
          from, to = line.split("\t")
          [from, to] if to && !from.start_with?('#')
        end.to_h
      end

      def replace(html)
        html.gsub(ATTRIBUTE) do
          match = Regexp.last_match
          found = replaced[CGI.unescapeHTML(match[2] || match[3]).gsub(/\s+/, '')]
          found ? %(#{match[1]}="#{found}") : match[0]
        end
      end

      # The path sits in an attribute, so a space in it is written as an escape.
      def move(html)
        return html if moved.empty?

        html.gsub(LINKED_PATH) do
          match = Regexp.last_match
          found = moved[decode(match[2])]
          "#{match[1]}#{found ? found.gsub(' ', '%20') : match[2]}#{match[3]}"
        end
      end

      def decode(path)
        text = CGI.unescapeHTML(path.split('?').first.to_s)
        text.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr }
      end

      # Only an anchor whose own words are a mirror pointer is dropped, and only when it
      # sits beside another link to the same file: after it, or before the link that
      # carries the wording. A file needed again further down keeps its own link there.
      def drop_duplicate_pointers(html)
        anchors = html.scan(ANCHOR).map { |quoted, bare, label| [quoted || bare, label] }
        dropped = anchors.each_index.select { |at| beside_its_file?(anchors, at) }
        return html if dropped.empty?

        at = -1
        tidy(html.gsub(ANCHOR) { dropped.include?(at += 1) ? '' : Regexp.last_match[0] })
      end

      def beside_its_file?(anchors, at)
        href, label = anchors[at]
        return false unless href.match?(LIVE_URL) && pointer?(label)

        follows = at.positive? && anchors[at - 1].first == href
        follows || worded_next?(anchors[at + 1], href)
      end

      def worded_next?(after, href) = after&.first == href && !pointer?(after[1])

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

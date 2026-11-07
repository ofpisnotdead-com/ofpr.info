module Ofpr
  # The download host the articles were written against, ftp.armedassault.info, is gone.
  # Every file it served is on files.ofpisnotdead.com under `files` plus the same path,
  # which is how the articles that link to both already write it. Most
  # articles already link there as well, as a second "FTP#2" pointer beside the first
  # link. Pointing the dead url at the live host would leave those two links on the same
  # file, so the pointer goes with it and the link that carries the wording stays. The
  # surviving links are all written to https, which the host answers and they did not.
  module Links
    DEAD = %r{https?://ftp\.armedassault\.info/}i
    INSECURE = %r{http://files\.ofpisnotdead\.com/}i
    LIVE = 'https://files.ofpisnotdead.com/files/'.freeze
    SECURE = 'https://files.ofpisnotdead.com/'.freeze
    LIVE_URL = %r{https://files\.ofpisnotdead\.com/}i

    ANCHOR = %r{<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>}mi
    # A link that only says which mirror it is: FTP#2, (from mirror #2), and the like.
    POINTER = /\b(?:ftp|mirror)\s*#?\s*\d\b/i
    EMPTY_WRAPPER = %r{<(small|center|b)>\s*</\1>}i
    EMPTY_SMALL = %r{(?:&nbsp;|\s)*<small>\s*</small>}i
    # "from <a>FTP#1</a> or <a>FTP#2</a>" can lose both of its links to another block.
    DANGLING_OR = %r{\s+or\b\s*(?=</)}i

    class << self
      def repair(html)
        text = html.to_s.gsub(DEAD, LIVE).gsub(INSECURE, SECURE)
        drop_duplicate_pointers(text)
      end

      def dead?(html) = html.to_s.match?(DEAD)

      private

      # Only an anchor whose own words are a mirror pointer is dropped, and only when the
      # file it points at is already linked somewhere else in the same article.
      def drop_duplicate_pointers(html)
        seen = Hash.new(0)
        html.scan(ANCHOR) { |href, _| seen[href] += 1 if href.match?(LIVE_URL) }
        return html if seen.values.none? { |n| n > 1 }

        kept = Hash.new(0)
        out = html.gsub(ANCHOR) do |anchor|
          href = Regexp.last_match(1)
          label = Regexp.last_match(2)
          next anchor unless seen[href] > 1 && pointer?(label)

          kept[href] += 1
          # The last one standing is left alone, so a file never loses every link.
          kept[href] == seen[href] ? anchor : ''
        end
        tidy(out)
      end

      def pointer?(label)
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

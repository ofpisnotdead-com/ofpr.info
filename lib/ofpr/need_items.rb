require 'uri'
require_relative 'links'

module Ofpr
  module NeedItems
    LINK = /(?<!!)\[((?:[^\[\]]|\[[^\]]*\])*)\]\((<[^>]*>|[^)]*)\)/
    IN_LINK = /\A[\s*_]*\[/
    SIZE = /\[\s*([\d.,]+\s*[kKmMgG]?[bB])\s*\]/
    MIRROR = /(?:ftp|mirror)\s*#?\s*(\d)/i
    HOSTS = /\A(?:ftp|mirror)\s*#?\s*\d\z|\A(?:download|here|link)\z/i
    NOISE = /\A[\s*_+,&:-]+|[\s*_+,&:-]+\z/
    LABEL_NOISE = /need'?s?\s*:|optional\s*:|download|\((?:ftp|mirror)\s*#?\s*\d\)|(?:ftp|mirror)\s*#?\s*\d/i
    NUMBERED = /\A(?:\d+\\?\.|[-*+])\s*/
    SKIPPED = /\A(?:or|and|update|none|\+)\z|\Aby\s/i
    FROM = /\s*\bfrom[\s*_]*\z/i
    CUT = /\[[^\]]*\z/
    POSSESSIVE = /\A[^\s\[]+['\u00B4]s\z/
    NO_SIZE = /\[\s*[kmg]?b\s*\]/i
    DECORATION = %r{!\[[^\]]*\]\(/ofpgm/images/[^)]*\)}
    INTERNAL = %r{\A/?(?:[a-z-]+/)*(\d+-[\w-]*)(?:\.html)?\z}

    class << self
      def of(markdown)
        joined(markdown.lines(chomp: true)).flat_map { |line| line_items(line.gsub(DECORATION, '')) }
      end

      def clean(text)
        text.gsub(SIZE, ' ').gsub(NO_SIZE, ' ').gsub(LABEL_NOISE, ' ').delete('*').squeeze(' ').gsub(NOISE, '').strip
      end

      private

      # "Name [size] from" ends a line whose link the next one carries, when it does,
      # and a stray line break can cut a size or a name in two, even across a blank line.
      def joined(lines)
        lines.each_with_object([]) do |line, out|
          last = out.last
          next if line.strip.empty? && cut?(last)

          hanging?(last, line) ? out[-1] = "#{last.rstrip} #{line.strip}" : out << line
        end
      end

      def hanging?(last, line) = cut?(last) || (unlinked?(last) && last.match?(FROM) && line.match?(IN_LINK))

      def cut?(line) = unlinked?(line) && (line.match?(CUT) || line.strip.match?(POSSESSIVE))

      def unlinked?(line) = line && !line.match?(LINK)

      def line_items(line)
        found, rest = linked_items(line)
        tail = rest.gsub(NOISE, '')
        found << plain_item(tail) if found.empty? && !tail.empty?
        found.compact
      end

      def linked_items(line)
        last = 0
        found = []
        line.to_enum(:scan, LINK).each do
          match = Regexp.last_match
          before = line[last...match.begin(0)]
          last = match.end(0)
          add_link(found, match[1], bare(match[2]), before)
        end
        [found, line[last..].to_s]
      end

      def add_link(found, label, url, before)
        return if label.strip.start_with?('![')
        return found.last[:alt] = address(url) if other_mirror?(found, label, before)

        found << link_item(label, url, before)
      end

      # "... from [FTP#1](a) or [FTP#2](b)" offers the same pack from a second mirror.
      def other_mirror?(found, label, before)
        found.any? && label.delete('*_').strip.match?(HOSTS) && before.gsub(NOISE, '').strip.match?(/\A(?:or)?\z/i)
      end

      def link_item(label, url, before)
        name = name_of(label, before.to_s)
        {kind: kind(url), name: name.empty? ? file_of(url) : name, url: address(url),
         file: file_of(url), size: (label[SIZE, 1] || before.to_s[SIZE, 1])&.strip,
         mirror: (label[MIRROR, 1] || before.to_s[MIRROR, 1])&.to_i}
      end

      # A link labelled only with its mirror or its site, as in "JAM 3 [14,2 MB] from
      # [FTP#1]" or "Mapfact Barracks [2,7 MB] from [Mapfact]", is named by the text in
      # front of it.
      def name_of(label, before)
        named = clean(label)
        lead = before.match?(FROM) ? clean(before.sub(FROM, '')) : ''
        return lead unless lead.empty?
        return named unless named.empty? || label.delete('*_').strip.match?(HOSTS)

        clean(before.sub(FROM, ''))
      end

      def plain_item(text)
        name = clean(text.sub(NUMBERED, '').sub(FROM, ''))
        name.empty? || name.match?(SKIPPED) ? nil : {kind: 'plain', name: name, size: text[SIZE, 1]&.strip}
      end

      def kind(url)
        return 'file' if url.start_with?(Links::SECURE, '/ofpgm/')
        return 'page' if url.match?(INTERNAL)

        'link'
      end

      def address(url)
        return url unless url.match?(INTERNAL)

        url.start_with?('/') ? "#{url.delete_suffix('.html')}.html" : "/#{url[INTERNAL, 1]}.html"
      end

      def file_of(url)
        return nil unless kind(url) == 'file'

        URI::DEFAULT_PARSER.unescape(File.basename(url.split('?').first.to_s))
      end

      def bare(url) = url.delete_prefix('<').delete_suffix('>')
    end
  end
end

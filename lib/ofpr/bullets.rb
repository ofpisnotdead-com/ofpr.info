module Ofpr
  module Bullets
    ITEM = %r{<p style="padding-left: *(\d+)px;">\s*&gt;\s*(.*?)</p>}m
    RUN = /(?:#{ITEM}\s*)+/m

    class << self
      def repair(html)
        html.to_s.gsub(RUN) { |run| list(run.scan(ITEM)) }
      end

      private

      # Each distinct indent is one level deeper than the one before it.
      def list(items)
        steps = items.map { |indent, _| indent.to_i }.uniq.sort
        depth = 0
        html = items.each_with_object(+'') do |(indent, text), out|
          want = steps.index(indent.to_i) + 1
          out << ('<ul>' * (want - depth)) if want > depth
          out << ('</li></ul>' * (depth - want)) << '</li>' if want < depth
          out << '</li>' if want == depth && depth.positive?
          out << "<li>#{text.strip}"
          depth = want
        end
        "#{html}</li>#{'</ul>' * depth}"
      end
    end
  end
end

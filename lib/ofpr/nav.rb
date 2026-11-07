module Ofpr
  # The menu is the capture's own markup, so the only thing to compute is which item is
  # active: the matching link, the list item around it, and the parent that owns the
  # dropdown it sits in.
  class Nav
    ACTIVE = ' active'.freeze

    def initialize(html)
      @html = html
    end

    def for_path(path)
      html = strip_active(@html)
      at = html.index(%(<a href="#{path}"))
      return html unless at

      marks = [at, li_before(html, at)]
      parent = parent_of(html, at)
      marks.concat(parent) if parent
      insert(html, marks)
    end

    private

    def strip_active(html)
      html.gsub(/class="([^"]*)"/) do
        tokens = Regexp.last_match(1).split.reject { |t| t == 'active' }
        if tokens.empty?
          'class=""'
        else
          %(class="#{' ' if Regexp.last_match(1).start_with?(' ')}#{tokens.join(' ')}")
        end
      end
    end

    def li_before(html, at) = html.rindex('<li', at)

    # A level-1 link sits inside the childcontent block of its parent item, so the
    # parent is the list item and link just before that block opens.
    def parent_of(html, at)
      nested = html.rindex('<ul class="gkmenu level1"', at)
      closed = html.rindex('</ul>', at)
      return nil if nested.nil? || (closed && closed > nested)

      block = html.rindex('<div class="childcontent">', at)
      link = block && html.rindex('<a ', block)
      link && [link, html.rindex('<li', link)]
    end

    # Rewrites from the back so earlier offsets stay valid.
    def insert(html, offsets)
      offsets.compact.sort.reverse_each do |at|
        tag_end = html.index('>', at)
        tag = html[at...tag_end]
        html = if tag.include?('class="')
                 html[0...at] + tag.sub(/class="([^"]*)"/) { %(class="#{Regexp.last_match(1)}#{ACTIVE}") } +
                   html[tag_end..]
               else
                 # Joomla writes the space in even when active is the only class.
                 %(#{html[0...at]}#{tag} class=" active"#{html[tag_end..]})
               end
      end
      html
    end
  end
end

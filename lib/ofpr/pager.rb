module Ofpr
  # Joomla's pagination markup, reproduced from the captured pages: a window of the
  # current page plus or minus two, clipped to the range, with an ellipsis on either side
  # when the window does not reach the end.
  class Pager
    WINDOW = 2
    # Up to six pages are listed in full; beyond that only a window around the current
    # one, which is what the captured pagers show.
    ALL_UP_TO = 6

    # com_search's pager leaves its list unclosed; K2's closes it. Reproduced rather
    # than corrected so a diff against the captured pages stays empty.
    def initialize(base, start, total, per_page: Article::PER_PAGE, close_list: true)
      @close_list = close_list
      @base = base
      @per_page = per_page
      @total = total.to_i
      @pages = [(@total.to_f / per_page).ceil, 1].max
      @current = (start.to_i / per_page).clamp(0, @pages - 1) + 1
    end

    # What the modern pager reads; `to_html` below is the captured markup, for the
    # facsimile, and the two have to agree about which page is which.
    attr_reader :current, :pages

    def window = (first..last).to_a

    def url_for(page) = url(offset(page))

    def previous_url = @current > 1 ? url_for(@current - 1) : nil

    def next_url = @current < @pages ? url_for(@current + 1) : nil

    def to_html
      return '' if @pages < 2

      items = (leading + numbers + trailing).join
      %(<nav class="pagination"><ul>#{items}#{'</ul>' if @close_list}</nav>)
    end

    private

    def leading
      back = @current > 1
      items = [edge('start', 'Start', 0, back), edge('prev', 'Prev', offset(@current - 1), back)]
      first > 1 ? items << ellipsis : items
    end

    def numbers = (first..last).map { |page| number(page) }

    def trailing
      on = @current < @pages
      items = last < @pages ? [ellipsis] : []
      items + [edge('next', 'Next', offset(@current + 1), on),
               edge('end', 'End', offset(@pages), on),
               %(<li class="counter">Page #{@current} of #{@pages}</li>)]
    end

    def first = @pages <= ALL_UP_TO ? 1 : [@current - WINDOW, 1].max

    def last = @pages <= ALL_UP_TO ? @pages : [@current + WINDOW, @pages].min

    def offset(page) = (page - 1) * @per_page

    # Even the first page is linked with an explicit start, as the capture does.
    def url(start) = "#{@base}?start=#{start}"

    def ellipsis = '<li><span>&hellip;</span></li>'

    def edge(name, label, start, enabled)
      inner = if enabled
                %(<a title="#{label}" href="#{url(start)}" class="pagenav">#{label}</a>)
              else
                %(<span class="pagenav">#{label}</span>)
              end
      %(<li class="pagination-#{name}">#{inner}</li>)
    end

    def number(page)
      return %(<li><span class="pagenav">#{page}</span></li>) if page == @current

      %(<li><a title="#{page}" href="#{url(offset(page))}" class="pagenav">#{page}</a></li>)
    end
  end
end

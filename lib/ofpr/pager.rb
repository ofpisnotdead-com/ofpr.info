module Ofpr
  # Which pages a listing links to: a window of the current page plus or minus two,
  # clipped to the range. Up to six pages are listed in full, which is the rule the
  # captured pagers follow and the one `rake compare` holds the page count to.
  class Pager
    WINDOW = 2
    ALL_UP_TO = 6

    attr_reader :current, :pages

    def initialize(base, start, total, per_page: Article::PER_PAGE)
      @base = base
      @per_page = per_page
      @total = total.to_i
      @pages = [(@total.to_f / per_page).ceil, 1].max
      @current = (start.to_i / per_page).clamp(0, @pages - 1) + 1
    end

    def window = (first..last).to_a

    def url_for(page) = "#{@base}#{@base.include?('?') ? '&' : '?'}start=#{(page - 1) * @per_page}"

    def previous_url = @current > 1 ? url_for(@current - 1) : nil

    def next_url = @current < @pages ? url_for(@current + 1) : nil

    private

    def first = @pages <= ALL_UP_TO ? 1 : [@current - WINDOW, 1].max

    def last = @pages <= ALL_UP_TO ? @pages : [@current + WINDOW, @pages].min
  end
end

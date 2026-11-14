module Ofpr
  # A page for each newsmaker with every story they wrote. The old site linked only one
  # author, by the number of their Joomla profile, which still answers here.
  module Authors
    def author_page(slug)
      redirect page_url("/author/#{slug.sub(/\A\d+-/, '')}"), 301 if slug.match?(/\A\d+-/)

      @start = params['start'].to_i
      @author, @total, @articles = Article.by_author(slug, start: @start, per_page: per_page)
      halt 404 unless @author

      @page_title = "News by #{@author}"
      @canonical = "/author/#{slug}"
      @nav_path = '/'
      @pager_base = page_url(@canonical)
      erb :listing
    end
  end
end

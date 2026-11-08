module Ofpr
  module Redirects
    def showthis(old_id)
      withdrawn if old_id && Withdrawn.include?(OldId[old_id]&.[](:article_id))
      old_id ? moved_to(Conversion.article_for(old_id)) : river
    end

    def withdrawn
      @page_title = 'Private article'
      halt 410, erb(:withdrawn)
    end

    def moved_to(article)
      halt 404 unless article

      redirect page_url(article[:url_path]), 301
    end

    def convert
      @page_title = 'Convert an old link'
      @canonical = '/convert'
      @link = params['link'].to_s
      @result = Conversion.of(@link)
      erb :convert
    end
  end
end

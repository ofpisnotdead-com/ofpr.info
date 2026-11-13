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

    def kept_query = request.query_string.empty? ? '' : "?#{request.query_string}"

    def hosted(name, rest)
      site = Hosted[name]
      halt 404 unless site&.enabled?
      redirect "/_hosted/#{name}/", 301 unless rest
      serve_hosted(site, request.path_info.delete_prefix("/_hosted/#{name}/"))
    end

    def serve_hosted(site, path)
      index = site.fetch("#{path}index.html") if site.folder?(path, request.query_string)
      return deliver(index) if index

      target = site.target(path, request.query_string)
      redirect "#{request.path_info.delete_suffix(path)}#{target}", 301 if target
      deliver(site.fetch(path) || halt(404))
    end

    def deliver(found)
      redirect found.redirect, 302 if found.redirect
      cache_control :public, max_age: 86_400
      send_file found.file if found.file
      content_type found.type || 'application/octet-stream'
      found.body
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

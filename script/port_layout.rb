# Builds the views from the captured pages so the markup is the rebuild's own. Run once
# and commit the result; it is kept so the port can be redone if the capture changes.
#
#   ruby script/port-layout.rb [capture-root]
require 'fileutils'

ROOT = ARGV[0] || File.expand_path('../../ofp-archive-catalog/ofpr-mirror', __dir__)
VIEWS = File.expand_path('../views', __dir__)
MAINBODY = '<section id="gkMainbody">'.freeze

def read(name) = File.read(File.join(ROOT, name), encoding: 'UTF-8')

# Captured links carry wget's rewriting: a query became part of the filename and every
# page gained .html. Undo that so the markup points at the app's own urls.
def links(html)
  html
    .gsub(%r{(["'])/?index\.html%3Fstart=(\d+)\.html}, '\1/?start=\2')
    .gsub(%r{(["'])/?index\.html(?=["'#])}, '\1/')
    .gsub(%r{(["'])/?((?:[a-z0-9-]+/)*)(\d+-[^"'/]*?)\.html}, '\1/\2\3')
    .gsub(%r{(["'])/?((?:[a-z0-9-]+/)+?[a-z0-9-]+)\.html%3Fstart=(\d+)\.html}, '\1/\2?start=\3')
    .gsub(%r{(["'])/?((?:[a-z0-9-]+/)*[a-z0-9-]+)\.html(?=["'#])}, '\1/\2')
    .gsub(%r{(["'])/?search\.html%3F([^"']*?)\.html}, '\1/search?\2')
    .gsub(%r{(["'])/?component/search/index\.html%3F[^"']*}, '\1/search')
    .gsub('%3F', '?')
    .gsub('&amp;amp;', '&amp;')
end

# Assets kept their query string in the filename; assets:normalise gave them the names a
# browser asks for, so the links lose the query too.
def assets(html)
  html.gsub(%r{(["'])/?((?:templates|media|images|plugins)/[^"']*)}) do
    # Read both groups before transforming: a regex call inside the block would
    # replace the match data this needs.
    quote = Regexp.last_match(1)
    path = Regexp.last_match(2)
    "#{quote}/#{path.delete_suffix('.html').sub(%r{\?[^/]*\z}, '')}"
  end
end

# The cookie-consent plugin is reproduced but switched off by default. Its three
# stylesheets 404 on test.ofpr.info as well, so the notice renders unstyled while
# magnific-popup holds the body scroll, and a first visit can neither read it nor
# scroll past. CONSENT=1 restores it, which is what the comparison runs with.
def consent(html)
  html
    .gsub(/<link[^>]*fmalertcookies[^>]*>/) { "<% if consent? %>#{Regexp.last_match(0)}<% end %>" }
    .gsub(%r{<script[^>]*>(?:(?!</script>).)*fmalertcookies(?:(?!</script>).)*</script>}m) do
      "<% if consent? %>#{Regexp.last_match(0)}<% end %>"
    end
end

def clean(html) = consent(assets(links(html)))

# The mainbody section ends at its matching close, which is the only boundary every
# page type shares: a K2 listing, an article and com_search all nest differently inside.
def mainbody(html)
  open_at = html.index(MAINBODY)
  depth = 0
  cursor = open_at
  html.scan(%r{<section\b|</section>}) do
    at = Regexp.last_match.begin(0)
    next if at < open_at

    depth += Regexp.last_match[0].start_with?('</') ? -1 : 1
    if depth.zero?
      cursor = at
      break
    end
  end
  [open_at, cursor]
end

# Walks from an opening tag to its matching close, which plain regex cannot do.
def balanced(html, open_tag, close_tag, from)
  depth = 0
  cursor = from
  html.scan(/#{Regexp.escape(open_tag)}|#{Regexp.escape(close_tag)}/) do
    at = Regexp.last_match.begin(0)
    next if at < from

    depth += Regexp.last_match[0] == close_tag ? -1 : 1
    if depth.zero?
      cursor = at + close_tag.length
      break
    end
  end
  cursor
end

# Shared head edits: the title, canonical and description are the only per-page parts.
def parameterise(head)
  head
    .sub(%r{<title>[^<]*</title>}, '<title><%= page_title %></title>')
    .sub(%r{<link href="[^"]*" rel="canonical" />}, '<link href="<%= canonical %>" rel="canonical" />')
    .gsub(%r{<meta name="twitter:title" content="[^"]*" />},
      '<meta name="twitter:title" content="<%= page_title %>" />')
    .gsub(%r{<meta name="author" content="[^"]*" />},
      '<meta name="author" content="<%= @article[:author] %>" />')
    .gsub(%r{<meta name="(description|twitter:description)" content="[^"]*" />}) do
      %(<meta name="#{Regexp.last_match(1)}" content="<%= meta_description %>" />)
    end
    .sub(%r{<script type="application/ld\+json">.*?</script>}m,
      '<script type="application/ld+json"><%== ld_json %></script>')
end

# Wraps the region from `from` up to and including the first `stop` after it, so the
# search page can leave it out.
def wrap_unless_search(html, from, stop)
  raise "not found: #{from}" unless (at = html.index(from))

  to = html.index(stop, at) + stop.length
  "#{html[0...at]}<% unless search_page? %>#{html[at...to]}<% end %>#{html[to..]}"
end

def chrome(page)
  html = read(page)
  from, to = mainbody(html)
  [clean(html[0...from]), clean(html[to..])]
end

def write(name, body)
  File.write(File.join(VIEWS, name), "#{body.strip}\n")
  puts "#{name.ljust(18)} #{body.bytesize} bytes"
end

head, foot = chrome('index.html')

# The head differs per page only in the title, the description and canonical metadata,
# and the structured-data block an article carries.
head = parameterise(head)

# The search page carries neither the social metadata, the canonical and opensearch
# links nor the top module block, and it alone shows the site description.
SITE_DESCRIPTION = 'OFP / Arma:CWA database of community-made content. Addons, Mods, ' \
                   'Missions, Campaigns, Tools. OFP.INFO / OFPR.INFO backup.'.freeze

['<meta name="twitter:card"', '<meta name="twitter:title"',
 '<link href="<%= canonical %>"', '<link href="/search" rel="search"'].each do |tag|
  head = wrap_unless_search(head, tag, '/>')
end
# The capture puts it immediately after the keywords meta, not at the end of the head.
head = head.sub(%r{(<meta name="keywords"(?:(?!/>).)*/>)}m) do
  %(#{Regexp.last_match(1)}\n\t<% if search_page? %><meta name="description" ) +
    %(content="#{SITE_DESCRIPTION}" /><% end %>)
end

top_at = head.rindex('<section', head.index('id="gkTop1"'))
top_to = balanced(head, '<section', '</section>', top_at)
raise 'gkTop1 did not close' unless top_to > top_at

head = "#{head[0...top_at]}<% unless search_page? %>#{head[top_at...top_to]}<% end %>#{head[top_to..]}"

# The menu is static markup whose only dynamic part is which item is active, so it is
# lifted out whole and marked at render time.
menu_at = head.index('<ul class="gkmenu level0">')
menu_to = balanced(head, '<ul', '</ul>', menu_at)
File.write(File.join(VIEWS, 'nav.html'), head[menu_at...menu_to])
puts "#{'nav.html'.ljust(18)} #{menu_to - menu_at} bytes"
head = "#{head[0...menu_at]}<%== nav %>#{head[menu_to..]}"

write('layout.erb', "#{head}#{MAINBODY}\n<%== yield %>\n#{foot}")

# An article page loads a different asset set in a different order, so it carries its
# own layout rather than the river's head with additions.
article_chrome, article_foot = chrome('2679-opflashpoint-it.html')
article_chrome = parameterise(article_chrome)
menu_at = article_chrome.index('<ul class="gkmenu level0">')
menu_to = balanced(article_chrome, '<ul', '</ul>', menu_at)
article_chrome = "#{article_chrome[0...menu_at]}<%== nav %>#{article_chrome[menu_to..]}"
write('article_layout.erb',
  "#{article_chrome}#{MAINBODY}\n<%== yield %>\n#{article_foot}")

def inner(page)
  html = read(page)
  from, to = mainbody(html)
  clean(html[(from + MAINBODY.length)...to])
end

# K2 splits a listing into a leading group and the rest: five groupPrimary items in
# itemListPrimary, then five groupSecondary in itemListSecondary.
LEADING = 5
def item_call(group, nodate)
  %(<%== erb :_item, locals: {article: article, group: '#{group}', nodate: #{nodate}} %>)
end

def listing(pager_call, nodate: false)
  <<~ERB
    <div id="k2Container" class="itemListView">
    	<div class="itemListCategoriesBlock"></div>
    	<div class="itemList">
    		<div id="itemListPrimary">
    <% @articles.first(#{LEADING}).each do |article| %>#{item_call('groupPrimary', nodate)}<% end %>
    		</div>
    		<div id="itemListSecondary">
    <% @articles.drop(#{LEADING}).each do |article| %>#{item_call('groupSecondary', nodate)}<% end %>
    		</div>
    	</div>
    	#{pager_call}
    </div>
  ERB
end

item = inner('index.html')[%r{<div class="itemContainer.*?<div class="clr"></div>}m]
write('_item.erb', item
  .sub('<article class="itemView groupPrimary">',
    %(<article class="itemView <%= group %><%= ' itemIsFeatured' if article[:featured] %>">))
  .sub('<div class="itemBody">', %(<div class="itemBody<%= ' nodate' if nodate %>">))
  .sub(%r{(<ul>.*?</ul>)}m, '<% unless nodate %>\\1<% end %>')
  .sub(%r{<a href="[^"]*">[^<]*</a>}, '<a href="<%= article[:url_path] %>"><%= article[:title] %></a>')
  .sub(%r{<div class="itemIntroText">.*?(?=\s*</div>\s*</div>)}m,
    '<div class="itemIntroText"><%== body_html(article) %>')
  .sub(%r{<time datetime="[^"]*">[^<]*</time>},
    '<time datetime="<%= stamp(article[:published_at]) %>">' \
    '<%= article[:published_at]&.strftime("%B %-d, %Y") %></time>')
  .sub(%r{<a rel="author" href="[^"]*">[^<]*</a>},
    '<a rel="author" href="/"><%= article[:author] %></a>'))

write('river.erb', listing("<%== pager('/', @start, @total) %>"))
write('section.erb', listing(%{<%== pager("/#{@section}", @start, @total) %>}, nodate: true))

# An article page: the same chrome, with one item in an itemView container.
article = inner('2679-opflashpoint-it.html')
write('article.erb', article
  .sub(%r{<h1[^>]*>.*?</h1>}m, '<h1><%= @article[:title] %></h1>')
  .sub(%r{<li>Written by&nbsp;.*?</li>}m,
    '<% if river_article? %><li>Written by&nbsp;<%== author_link %></li><% end %>')
  .sub(%r{<li><span>Published in</span> <a href="[^"]*">[^<]*</a></li>},
    '<li><span>Published in</span> <a href="<%= section_path %>">' \
    '<%= @article[:section_label] %></a></li>')
  .sub(%r{<li>Read \d+ times </li>}, '<li>Read <%= @article[:hits] %> times </li>')
  .sub(%r{<div class="itemIntroText">.*?(?=\s*</div>\s*</div>)}m,
    '<div class="itemIntroText"><%== body_html(@article) %>')
  .sub(%r{<div class="itemFullText">.*?(?=\s*</div>)}m,
    '<div class="itemFullText"><%== body_html(@article) %>')
  .sub(%r{<time datetime="[^"]*">[^<]*</time>},
    '<time datetime="<%= stamp(@article[:published_at]) %>">' \
    '<%= @article[:published_at]&.strftime("%B %-d, %Y") %></time>')
  .sub(%r{<a rel="author" href="[^"]*">[^<]*</a>},
    '<a rel="author" href="/"><%= @article[:author] %></a>'))

# The search page: the result list is com_search's, not K2's.
search = inner('search.html?searchword=fliper&ordering=newest&searchphrase=all.html')
result = search[%r{<dt class="result-title">.*?</dd>\s*(?=<dt class="result-title">)}m]
search = search
  .sub(/(name="searchword"[^>]*?value=")[^"]*/) { "#{Regexp.last_match(1)}<%= @query.word %>" }
  .sub(%r{<p><strong>Total: \d+ results found\.</strong></p>},
    '<% unless @query.blank? %><p><strong>Total: <%= @total %> results found.</strong></p>' \
    '<% end %>')
  .gsub(%r{(<input type="radio" name="searchphrase" id="searchphrase(\w+)" value="\2")[^/]*/>}) do
    %(#{Regexp.last_match(1)}<%= ' checked="checked"' if @query.phrase == '#{Regexp.last_match(2)}' %> />)
  end
search = search
  .gsub(%r{<option value="(\w+)"(?: selected="selected")?>([^<]*)</option>}) do
    value = Regexp.last_match(1)
    label = Regexp.last_match(2)
    next Regexp.last_match(0) unless %w[newest oldest popular alpha category].include?(value)

    %(<option value="#{value}"<%= ' selected="selected"' if @query.ordering == '#{value}' %>>#{label}</option>)
  end
  .sub(%r{<p class="counter">\s*Page \d+ of \d+\t?</p>},
    '<p class="counter"><%= page_counter %></p>')
  .sub(%r{<dl class="search-results">.*</dl>}m,
    "<dl class=\"search-results\">\n<% @articles.each do |article| %>" \
    "<%== erb :_result, locals: {article: article} %><% end %>\n</dl>")
  .sub(%r{<nav class="pagination">.*?</nav>}m, '<%== search_pager %>')
write('search.erb', search)

write('_result.erb', result
  .sub(%r{<a href="[^"]*">[^<]*</a>},
    '<a href="<%= article[:url_path] %>"> <%== highlight(article[:title]) %> </a>')
  .sub(/(<dd class="result-category"> <span class="small"> \()[^<]*(\))/,
    '\\1<%= article[:section] %>\\2')
  .sub(%r{(<dd class="result-created"> Created on )[^<]*(</dd>)},
    '\\1<%= article[:published_at]&.strftime("%d %B %Y") %> \\2')
  .sub(%r{(<dd class="result-text">).*?(</dd>)}m, '\\1<%== snippet(article) %>\\2'))

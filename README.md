# ofpr.info

Serves the ofpr.info archive at the urls test.ofpr.info has, with search and images on
the CDN. English only for now.

The site renders from the markdown and the blocks the import reads off each stored
body. `body_html` is never written to and never rendered: it is the archival record,
and everything shown is derived from it at import time.

Content comes from the static capture in `../ofp-archive-catalog/ofpr-mirror`: 10,246
article pages whose path below the capture root is the url, so nothing has to be mapped.
`../ofp-archive-catalog/gen-docs/ofpr-info-revival-plan.md` has the background.

## Start

    bin/setup     # postgres in docker, gems, migrate, seed, link the mirror chrome
    bin/dev       # http://localhost:9292

The seed is `db/seed.json`, 81 articles across the river and all 17 sections plus the
one menu page, so development needs neither the 6.9 GB mirror nor a full import.

## Tasks

    rake test            rake db:migrate      rake mirror:import   # all 10,246
    rake lint            rake db:seed         rake mirror:seed     # rebuild seed.json
    rake check           rake db:reset        rake assets:link     # article images -> public/
    rake compare         # check every captured listing against the data
    rake verify_captures # check the captures still match what test.ofpr.info serves
    rake links           # request every link a running app renders
    rake port:verify     # assert the markdown and the blocks lost nothing
    rake port:show URL=/path  # print one body as markdown

## Settings

    DATABASE_URL   postgres://ofpr:ofpr@localhost:5433/ofpr_development
    CDN_BASE       empty; set to https://files.ofpisnotdead.com/ofpr to move assets there
    MIRROR         ../ofp-archive-catalog/ofpr-mirror
    PORT           9292

The header banner is deliberately not the captured one: `public/images/banner.jpg` is
the same artwork with the old domain taken off the corner. The reference server points
the captures at it so the comparison stays about the layout rather than about that.

The fonts are linked over https, where the capture asks for them over http. A browser
refuses that on an https page, so test.ofpr.info renders its headings in Arial where
the design asks for Bitter. That is an artefact of how the mirror is hosted rather than
how the site looked, and the rebuild would inherit it the moment it went behind TLS.

The layout - stylesheets, fonts, logo - ships with the app under `public/`. The CDN is
only for article images: set `CDN_BASE` and `/ofpgm/...` redirects there, leave it unset
and they come from the mirror through the `public/ofpgm` symlink `rake assets:link`
makes.

## Urls

    /  /?start=N  /index.php          the news river, ten a page
    /<id>-<slug>                      a river article, 7,390 of them
    /<section>/<id>-<slug>            an addon, mission, utility or patch, 2,856
    /<section>  /<section>?start=N    a section listing
    /search?searchword=Q&...          Joomla's com_search contract, five a page
    /mods                             the one page the menu links straight to
    /ofpgm/<path>                     301 to the CDN

Root ids and section ids do not overlap, so every article has one url. The river holds
the articles with no section, newest id first; a sectioned one is reached through its
own listing. `/mods` is a K2 item like an article, but the menu link hides its title and
the capture never names its id, so it lives in `pages` keyed by its url.

The search box in the header posts to the site root, the way Joomla's `index.php` took
it, so `/` and `/index.php` accept that post and send the browser to the search url.

Search keeps com_search's parameters and its semantics: a term is matched as a
substring, not a stemmed word, so `martin` finds Martins and Aston Martin the way the
site did. Joomla's email cloaking replaced mailto links with a script and took their
visible text out of the body, so that text is read back out of the script and kept in
`cloak_text` for search; what is displayed stays as the capture has it. `searchphrase` of `all`, `any` or `exact` becomes an AND, an OR or a single
phrase, `ordering` is `newest`, `oldest` or `alpha`, results come five to a page and the
header prints `Total: N results found.`

## Downloads

The articles were written against `ftp.armedassault.info`, which is gone. Every file it
served is on `files.ofpisnotdead.com` under `files` plus the same path, which is how
the articles that link to both already write it, so `lib/ofpr/links.rb` moves the dead
url across on import. Most articles carried both links already, the second as a small
`FTP#2` pointer or a `downloadftp2.jpg` button beside the first, and moving the first
would have left two links on one file: the pointer goes and the link that carries the
wording stays. Where a file has nothing but pointers, the first of them stays, so the
button in the table is the one that survives and a file never loses its last link. The
surviving links are written to https, which the host answers and they did not. That is
8,524 dead urls and 7,880 duplicate links across 5,638 articles.

A file linked twice for other reasons is left alone: 103 articles name one in the prose
and again under a screenshot, which are two ways to reach it rather than two mirrors.

The search excerpts pay for it. com_search built them from the body as it was, pointers
and all, so taking the pointers out moves the chunk boundaries: 87 of the 176 captured
excerpts still carry the same words, where 144 did before the links were repaired. Working downloads are worth
more than excerpts that match an archive of dead links.

## Layout

`views/` is one layout, one stylesheet at `public/assets/ofpr.css` and one script, and
no framework. It renders from `body_blocks` and `body_markdown`, so an addon card is
laid out rather than printed as a 2003 table, and a download says its file name, size
and mirror.

Until this point the rebuild also served a facsimile of the captured markup and the
comparison diffed the two, tag for tag and pixel for pixel. That work is finished and
it is in the history: 1,064 of 1,064 captures identical, every page type but search
pixel for pixel, four defects found by the pixels that the markup diff had passed. The
design has replaced the markup, so comparing markup proves nothing any more.

What the comparison checks now is the thing worth keeping: **the data**.

    rake compare   1,825 captured listings, no server needed

For every captured listing - the river and all its pages, every section and its pages,
and all 36 searches - it reads the article ids out of the capture and asks the database
what belongs on that page. Same ids, same order, same number of pages. It is a wider
net than the old one, which sampled a few hundred pages over http: it reads the
captures straight off disk, so it covers all of them and needs nothing running.

It found something the old comparison could not. Article 3532 has an empty title and an
empty slug, so the capture links it as `3532-.html`; the id regex wanted a slug and
missed it on both sides equally, which is why diffing rendered pages against each other
never noticed. Checking against the data did.

Two checks are unchanged:

- **All 36 captured search pages return the same result ids in the same order**, with
  the same totals and page counts. No archive holds a search *results* page for this
  site - the Wayback Machine has 14 snapshots of the empty form at `/search.html`
  between 2018 and 2020 and the OpenSearch descriptor, but crawlers never submit a
  form, so the mirror's own captures of `fliper` and `martin` are the only reference
  there is.
- **56 of 56 captures the live host can still address are byte-identical to what
  test.ofpr.info serves**, so comparing against the captures is comparing against the
  live site. `rake verify_captures` checks this, politely paced.

The excerpt under a search result is read off the port, not off the stored html: the
prose of the matching article with a window taken around the first search word. The
rebuild used to reproduce com_search's own `prepareSearchContent` and `_smartSubstr`
chunking, and that is in the history too - of 176 captured excerpts 144 carried the
same words and 138 were byte-identical, and the rest could not be reconciled because
com_search walked `introtext` and `fulltext` as the database held them while we only
have the body as the page rendered it. The result *ids* still match, which is the part
that says the search is right.

    lib/ofpr/pager.rb          which pages a listing links to
    lib/ofpr/extractor.rb      a captured page -> a row
    lib/ofpr/article.rb        river, section, lookup, search
    lib/ofpr/page.rb           a page the menu links straight to
    lib/ofpr/search_query.rb   search parameters -> conditions and order
    lib/ofpr/markdown.rb       stored markup -> markdown
    lib/ofpr/blocks.rb         markdown -> cards, galleries, downloads, prose
    lib/ofpr/prose.rb          markdown -> html, and the plain text of it
    lib/ofpr/port.rb           what rake port:verify asserts about both
    lib/ofpr/presenter.rb      what the modern templates ask for
    lib/ofpr/menu.rb           the menu, as the captured one has it
    lib/ofpr/app.rb            routes

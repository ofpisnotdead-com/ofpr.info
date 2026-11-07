# ofpr.info

Serves the ofpr.info archive at the urls test.ofpr.info has, with search and images on
the CDN. English only for now.

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
    rake compare         # diff rendered pages against the captured ones
    rake verify_captures # check the captures still match what test.ofpr.info serves
    rake links           # request every link a running app renders
    rake assets:normalise  # give captured assets the names a browser asks for

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

The views are the rebuild's own markup, lifted from the captures by
`script/port_layout.rb` and committed. `rake compare` renders each captured page and
diffs the tag, class and id skeleton against it, ignoring text and whitespace.

What is verified, and how far:

- **1,064 of 1,064 comparable captures are identical**, across the river and its pages,
  articles at all three depths, section listings, search and the menu pages.
  Alongside the skeleton it compares the ids each listing lists, in order, and where
  every pager link points.
- **Every page type but search renders pixel for pixel identical** to its capture in
  the same browser at the same size, down to the last antialiased edge: eight pages
  each of the river, section listings and their pages, and articles at all three
  depths, forty-eight of forty-eight, plus the menu pages, `/index.php` and the empty
  search form. Only search results differ, and only in the excerpt text.
  `script/pixel_compare.py` checks one page of each type, `script/pixel_sweep.py` eight
  of each. Search results are the exception and the excerpt is why: of 176 captured
  excerpts 144 carry the same words, and the rest sit a word either side of a chunk
  boundary or on a different chunk.
- The skeleton cannot see text, colour or position, so the pixels are what check them,
  and they found four defects it had passed. Titles were escaped a second time, so
  `Lady&#039;s` printed literally on 994 articles. A search result printed the url
  section where the original prints the category it came from. Thirty-eight articles
  were mirrored with the site's own host written into their image urls, and that host
  answers nothing today, so their screenshots were holes. And the search box in the
  header posted to a route that did not exist.
- **All 36 captured search pages return the same result ids in the same order**, with
  the same totals and page counts. No archive holds a search *results* page for this
  site - the Wayback Machine has 14 snapshots of the empty form at `/search.html`
  between 2018 and 2020 and the OpenSearch descriptor, but crawlers never submit a
  form, so the mirror's own captures of `fliper` and `martin` are the only reference
  there is. The search region of those archived snapshots is identical to what the app
  renders, five years apart.
- **56 of 56 captures the live host can still address are byte-identical to what
  test.ofpr.info serves**, so comparing against the captures is comparing against the
  live site. `rake verify_captures` checks this, politely paced.
- **The 404 page is the site's own**, taken from the Wayback Machine: test.ofpr.info
  answers with nginx's default, but the archive caught the real Joomla error page in
  2021 and again in 2024, byte-identical apart from the cloak id. It is committed as
  `spec/fixtures/pages/error-404.html` and a spec holds the rendered page to it.
- The live host is a static file mirror and cannot serve this url space itself:
  `/2679-opflashpoint-it` answers 404 there, `/addons/aircrafts` redirects, and
  `?start=10` is ignored and returns page one. That is a hosting artefact, not the
  rebuild's behaviour, which is why the captures are the reference.

One limit, and it is in the reference rather than the app: **514 pages lost their
numbered pager links**, holding empty list items instead. The loss is not ours. Both
server trees carry it, test.ofpr.info serves it, and no paginated ofpr.info url was ever
captured by the Wayback Machine, so nothing intact exists to compare against. What
survived the loss - Start, Prev, Next, End and the page counter - is compared on those
pages, and the numbered links are verified against the 47 captures that kept theirs,
including the rule that six pages or fewer are listed in full.

The cookie-consent plugin is reproduced but off by default, and that is deliberate.
Its three stylesheets 404 on test.ofpr.info as well, so magnific-popup opens it as a
modal with no styles: the backdrop paints as a black band, `mfp-preloader` prints
`Loading...` into it, and `modal: true` holds the body scroll, so a first visit can
neither read the notice nor scroll past it. Rendering both pages in headless Chrome
shows it plainly - the live site's DOM carries thirteen tags ours does not, every one
of them the modal or the notice, and ours carries none the live site lacks. `CONSENT=1`
reproduces it for comparison; left off, the page renders and scrolls.

The comparison looks at what the app actually serves and sets the notice aside on the
capture when it is off, so the app you browse is the app that gets compared.

The rebuild's own IE conditional blocks are gone - the three `ie/*.css` files, `ie.js`,
`respond.js` and the html5 shim. They only ever loaded in IE 9 and older. Nothing else
changed with them: they sat inside `<!--[if ...]>` comments, which the comparison
strips from both sides anyway.

The excerpt under a search result follows com_search's own `prepareSearchContent` and
`_smartSubstr`: script blocks and curly tags go, a line breaking or block closing tag
becomes one space, the rest of the tags go without leaving a space, nothing normalises
the whitespace, and the text is then walked in chunks of 200 characters, each extended
to the next space, until one holds the term. Named entities are decoded first, because
a non-breaking space counted as six characters rather than one moves the boundary and
drops the last word.

Of 176 captured excerpts, 144 carry the same words as the capture and 138 are
byte-identical; of the other 32, fourteen end a word early or late and eighteen show a
different chunk.

The chunking itself is right: for articles 3818 and 5834 the capture's chunk is exactly
202 and 207 characters, which is exactly where `index(' ', 200)` falls in our own text.
What differs is the text being chunked. com_search walked the article as the database
held it, `introtext` and `fulltext`; the rebuild only has the body as the page rendered
it, and for those two the capture's excerpt is the opening chunk Joomla prints when the
search word is absent, while the word sits in plain text in the body we recovered. No
change to the algorithm can reconcile that, because the inputs differ.

One part of that gap did close. Joomla cloaked email addresses as the page was rendered,
so 675 bodies carry `This email address is being protected from spambots...` where the
stored article held the address itself. The visible text is recovered into `cloak_text`,
and putting it back before the chunking moved five more excerpts onto the same words.

    script/port_layout.rb      captures -> views, run once and committed
    script/reference_server.py serves the captures so a browser can render them
    script/pixel_compare.py    renders both and counts the pixels that differ
    script/pixel_sweep.py      the same, eight pages of every type
    lib/ofpr/skeleton.rb       the tag/class/id skeleton rake compare diffs
    lib/ofpr/pager.rb          Joomla's pagination markup
    lib/ofpr/nav.rb            marks the active menu item
    lib/ofpr/snippet.rb        the excerpt under a search result
    lib/ofpr/extractor.rb      a captured page -> a row
    lib/ofpr/article.rb        river, section, lookup, search
    lib/ofpr/page.rb           a page the menu links straight to
    lib/ofpr/search_query.rb   search parameters -> conditions and order
    lib/ofpr/renderer.rb       stored markup -> markup with CDN paths
    lib/ofpr/app.rb            routes

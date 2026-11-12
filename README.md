# ofpr.info

Serves the ofpr.info archive - Operation Flashpoint news, addons and missions from 2001
to 2019 - at the urls the site served them at. Sinatra, Sequel and PostgreSQL, with ERB
templates and one stylesheet served as they are.

The content is extracted from a static capture of the original site on every
`rake mirror:import`, so anything changed in the database is lost at the next import.
Repairs belong in `lib/ofpr/extractor.rb` or `lib/ofpr/links.rb`.

## Dependencies

- Ruby 4.0.9
- Docker, with compose available (it runs PostgreSQL)

## Run locally

```bash
bin/setup
bin/dev
```

Open http://localhost:9292

`bin/setup` seeds `db/seed.json`, which holds enough articles to cover the news river and
every section, so development needs neither the capture nor a full import.

The sites once hosted under `ofp.gamepark.cz/_hosted` answer at `/_hosted/<site>/`, from
their rebuilt files. `db/hosted/<site>.tsv`, written by the site's rebuild, says where each
old address leads, and `HOSTED_<SITE>` where the files are: a url, or a local directory.

```bash
HOSTED_OFPMM=/path/to/ofpmm/out bin/dev
```

## Run tests

```bash
bin/run rake check   # rubocop and rspec
bin/run rspec        # the specs alone
```

## More

`rake -T` lists the rest: importing the capture, rebuilding the seed, and the checks on
the markdown port and the listings.

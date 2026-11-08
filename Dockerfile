# The platform is pinned because the tag alone is not safe: on at least one developer
# machine `ruby:4.0-slim` resolves to a 386 image, and the cluster nodes are amd64.
ARG PLATFORM=linux/amd64

# The gems build here so the runtime image carries no compiler. nokogiri and pg are the
# two that need one.
FROM --platform=$PLATFORM ruby:4.0-slim AS gems

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential libpq-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' \
  && bundle install --jobs 4 \
  && rm -rf /usr/local/bundle/cache

FROM --platform=$PLATFORM ruby:4.0-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends libpq5 \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --uid 1000 --shell /usr/sbin/nologin ofpr

ENV RACK_ENV=production \
    BUNDLE_WITHOUT=development:test

WORKDIR /app
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --chown=ofpr:ofpr config.ru Gemfile Gemfile.lock ./
COPY --chown=ofpr:ofpr lib lib
COPY --chown=ofpr:ofpr views views
COPY --chown=ofpr:ofpr public public
COPY --chown=ofpr:ofpr db/migrations db/migrations
COPY --chown=ofpr:ofpr db/old_ids.tsv db/old_ids.tsv

USER ofpr
EXPOSE 9292

# The article images are not in here: they are 3.2 GB on the file server, and CDN_BASE
# points the pages at them.
CMD ["bundle", "exec", "puma", "--bind", "tcp://0.0.0.0:9292"]

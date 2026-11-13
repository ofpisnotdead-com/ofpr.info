require 'net/http'
require 'uri'

module Ofpr
  # Sites the community once hosted under ofp.gamepark.cz/_hosted, rebuilt as static files
  # and kept elsewhere. Each has a table in `db/hosted`, written by its rebuild, of where
  # an address of the old site leads now: the exact address first, then a prefix ending
  # in `*`. The files come from the site's backend, set in `HOSTED_<SITE>`: a url to fetch
  # them from, or a directory holding them.
  class Hosted
    DIR = File.expand_path('../../db/hosted', __dir__)
    # Fetched and passed on whole, so a thread is not held by a slow download; anything
    # bigger is sent to the backend instead.
    LIMIT = 2 * 1024 * 1024
    TIMEOUT = 5
    # The session id a forum wrote into its links, which no table keeps every value of.
    SESSION = /(?<=[?&])s=\h{32}(&|\z)/

    Fetched = Struct.new(:body, :type, :redirect, :file)

    def self.[](name)
      @sites ||= Dir[File.join(DIR, '*.tsv')].to_h do |file|
        site = File.basename(file, '.tsv')
        [site, new(file, ENV.fetch("HOSTED_#{site.upcase}", ''))]
      end
      @sites[name]
    end

    attr_reader :backend

    def initialize(file, backend)
      @backend = backend.delete_suffix('/')
      @exact = {}
      @prefixes = []
      File.foreach(file, chomp: true) do |line|
        key, target = line.split("\t")
        key.end_with?('*') ? @prefixes << [key.delete_suffix('*'), target] : @exact[key] = target
      end
    end

    def enabled? = !backend.empty?

    def folder?(path, query) = query.empty? && (path.empty? || path.end_with?('/'))

    # Where an address leads when it is not a file of the rebuild. An address that ran
    # code on the old site, a script or a directory, always leads somewhere.
    def target(path, query)
      key = query.empty? ? path : "#{path}?#{query}"
      found = exact(key) || exact(key.sub(SESSION, '').sub(/[?&]\z/, ''))
      return found if found || !dynamic?(path, query)

      @prefixes.find { |prefix, _| key.start_with?(prefix) }&.last
    end

    # The path as it was asked for, still escaped.
    def fetch(path)
      decoded = URI.decode_uri_component(path)
      return if decoded.split('/').include?('..')

      backend.match?(%r{\Ahttps?://}i) ? remote(path) : local(decoded)
    end

    private

    def exact(key) = @exact[key] || @exact[key.sub(%r{(\A|/)index\.php(?=\z|\?)}, '\1')]

    def dynamic?(path, query) = path.empty? || path.end_with?('/', '.php') || !query.empty?

    def local(path)
      file = File.join(backend, path)
      Fetched.new(file:) if File.file?(file)
    end

    def remote(path)
      uri = URI("#{backend}/#{path}")
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT,
        read_timeout: TIMEOUT) do |http|
        head = http.head(uri.request_uri)
        next unless head.is_a?(Net::HTTPOK)
        next Fetched.new(nil, nil, uri.to_s) if head.content_length.to_i > LIMIT

        response = http.get(uri.request_uri)
        Fetched.new(response.body, response.content_type) if response.is_a?(Net::HTTPOK)
      end
    rescue URI::Error, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout
      nil
    end
  end
end

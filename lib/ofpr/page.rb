module Ofpr
  # A page the menu links straight to. It is a K2 item like an article, but the menu
  # link hides the title block, and the capture never names its id, so the url is the
  # only key it has.
  module Page
    class << self
      def dataset = Database.connection[:pages]

      def by_url(url_path) = dataset[url_path: url_path]
    end
  end
end

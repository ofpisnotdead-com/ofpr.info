module Ofpr
  module Conversion
    OLD_ID = /[?&]showthis=(\d+)/
    NEW_ID = %r{/(\d+)-}
    DIGITS = /\A(\d+)\z/

    Result = Struct.new(:kind, :article, :old_id, :article_id, keyword_init: true) do
      def found? = kind == :found
    end

    class << self
      def of(text)
        text = text.to_s.strip
        return Result.new(kind: :empty) if text.empty?

        old = text[OLD_ID, 1] || text[DIGITS, 1]
        return from_old(Integer(old)) if old

        new = text[NEW_ID, 1]
        new ? from_new(Integer(new)) : Result.new(kind: :unreadable)
      end

      def article_for(old_id)
        row = OldId[old_id]
        row && row[:article_id] && Article.dataset[id: row[:article_id]]
      end

      private

      def from_old(old_id)
        row = OldId[old_id]
        return Result.new(kind: :unknown, old_id: old_id) unless row
        return Result.new(kind: :dropped, old_id: old_id) unless row[:article_id]

        article = Article.dataset[id: row[:article_id]]
        Result.new(kind: article ? :found : :absent, article: article,
          old_id: old_id, article_id: row[:article_id])
      end

      def from_new(article_id)
        article = Article.dataset[id: article_id]
        return Result.new(kind: :unknown, article_id: article_id) unless article

        Result.new(kind: :found, article: article, article_id: article_id)
      end
    end
  end
end

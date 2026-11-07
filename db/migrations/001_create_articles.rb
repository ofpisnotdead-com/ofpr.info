Sequel.migration do
  up do
    create_table(:articles) do
      Integer :id, primary_key: true
      String :slug, null: false
      String :url_path, null: false, unique: true
      String :section, null: false, default: ''
      String :title, null: false, default: ''
      String :description, text: true
      String :author
      DateTime :published_at
      DateTime :modified_at
      String :body_html, text: true, null: false

      index :section
      index :published_at
    end

    # Indexing the body with its tags stripped: the stored markup is the article, so the
    # tag names would otherwise dominate every document.
    run <<~SQL.chomp
      ALTER TABLE articles ADD COLUMN search_vector tsvector
        GENERATED ALWAYS AS (
          to_tsvector('english',
            coalesce(title, '') || ' ' || coalesce(author, '') || ' ' ||
            regexp_replace(coalesce(body_html, ''), '<[^>]*>', ' ', 'g'))
        ) STORED
    SQL
    run 'CREATE INDEX articles_search_idx ON articles USING gin (search_vector)'
  end

  down do
    drop_table(:articles)
  end
end

Sequel.migration do
  change do
    create_table(:pages) do
      String :url_path, primary_key: true
      String :title, null: false, default: ''
      String :description, text: true
      String :author
      String :author_url
      DateTime :published_at
      DateTime :modified_at
      String :body_html, text: true, null: false
    end
  end
end

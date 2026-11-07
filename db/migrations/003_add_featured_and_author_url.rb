Sequel.migration do
  change do
    alter_table(:articles) do
      # Both live only in the captured markup. K2 marks a few items featured, and that
      # shows on the listing rather than on the article, so it is read from the listing
      # captures. An author who had an account is rendered as a link.
      add_column :featured, TrueClass, default: false, null: false
      add_column :author_url, String
    end
  end
end

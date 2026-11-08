Sequel.migration do
  change do
    create_table(:old_ids) do
      Integer :old_id, primary_key: true
      Integer :article_id, index: true
    end
  end
end

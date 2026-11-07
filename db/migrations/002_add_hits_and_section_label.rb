Sequel.migration do
  change do
    alter_table(:articles) do
      # Both are shown in the article footer and exist only in the captured markup: the
      # hit counter was the rebuild's own, and the label is the original section name,
      # which differs from the path (`unofaddons/aircrafts` against `addons/aircrafts`).
      add_column :hits, Integer
      add_column :section_label, String
    end
  end
end

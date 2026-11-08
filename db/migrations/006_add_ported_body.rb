Sequel.migration do
  change do
    %i[articles pages].each do |table|
      alter_table(table) do
        # The body converted to markdown, and the structures that are not prose pulled
        # out of it. `body_html` is never written to: it is the archival record and the
        # facsimile renders from it, so a wrong conversion is re-run, never recovered.
        add_column :body_markdown, String, text: true
        add_column :body_blocks, :jsonb
        add_column :body_port, String
      end
    end
  end
end

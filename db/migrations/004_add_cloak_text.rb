Sequel.migration do
  change do
    alter_table(:articles) do
      # Joomla's email cloaking replaces a mailto link with a script, taking the link's
      # visible text out of the body. The script still carries that text, entity encoded,
      # and the site's own search matched on it, so it is kept for search alone: what is
      # displayed stays exactly as the capture has it.
      add_column :cloak_text, String, text: true
    end
  end
end

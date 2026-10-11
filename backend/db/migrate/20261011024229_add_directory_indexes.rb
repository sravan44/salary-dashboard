# Indexes justified by EXPLAIN ANALYZE on the 10k seed (docs/evidence/performance.md):
# - (full_name, id): the directory's default order. The first page went from sorting all rows to an
#   index walk (10.2 ms → 0.14 ms).
# - trigram GIN on the three searched columns: search is a substring match (ILIKE '%…%'), which a
#   btree can't serve; search-as-you-type went from scanning every row to an index lookup
#   (count 12.7 ms → 0.6 ms). pg_trgm ships with PostgreSQL (contrib) and managed hosts.
class AddDirectoryIndexes < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"
    add_index :employees, %i[full_name id], name: "index_employees_on_full_name_and_id"
    %i[full_name email employee_number].each do |column|
      add_index :employees, column, using: :gin, opclass: :gin_trgm_ops, name: "index_employees_on_#{column}_trgm"
    end
  end
end

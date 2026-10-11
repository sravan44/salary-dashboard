module Insights
  # Headline numbers for the dashboard tiles. Counts only; no money is added up here.
  # All six figures come from ONE pass over the population (GROUPING SETS); six separate GROUP BY
  # queries each re-read and re-joined the same rows (measured in docs/evidence/performance.md).
  class SummaryQuery
    Result = Data.define(:headcount, :countries_count, :currencies, :headcount_by_country, :headcount_by_department, :hires_by_year)

    def initialize(population)
      @relation = population.relation
    end

    def call
      groups = Hash.new { |hash, key| hash[key] = [] }
      ActiveRecord::Base.connection.select_all(sql).each do |row|
        dimension = %w[currency country department hire_year].find { |column| row["by_#{column}"].zero? }
        dimension ? groups[dimension] << [ row[dimension], row["n"] ] : groups["total"] << [ nil, row["n"] ]
      end

      Result.new(
        headcount: groups["total"].sum { |_, n| n },
        countries_count: groups["country"].size,
        currencies: largest_first(groups["currency"]).map { |currency, n| { currency:, headcount: n } },
        headcount_by_country: largest_first(groups["country"]).map { |code, n| { country_code: code, headcount: n } },
        headcount_by_department: largest_first(groups["department"]).map { |name, n| { department: name, headcount: n } },
        hires_by_year: groups["hire_year"].sort.map { |year, n| { year:, headcount: n } }
      )
    end

    private

    # GROUPING(x) is 0 on the rows grouped by x and 1 elsewhere, so each row says which figure it is.
    def sql
      rows = @relation.select("employees.country_code AS country", "employees.department AS department",
                              "current_comp.currency AS currency", "EXTRACT(YEAR FROM employees.hire_date)::int AS hire_year").to_sql
      <<~SQL.squish
        WITH pop AS (#{rows})
        SELECT GROUPING(currency) AS by_currency, GROUPING(country) AS by_country, GROUPING(department) AS by_department,
               GROUPING(hire_year) AS by_hire_year, currency, country, department, hire_year, COUNT(*) AS n
        FROM pop
        GROUP BY GROUPING SETS ((), (currency), (country), (department), (hire_year))
      SQL
    end

    # Largest first, ties alphabetical, so the order is stable.
    def largest_first(pairs) = pairs.sort_by { |key, n| [ -n, key.to_s ] }
  end
end

module Insights
  # Headline numbers for the dashboard tiles. Counts only; no money is added up here.
  class SummaryQuery
    Result = Data.define(:headcount, :countries_count, :currencies, :headcount_by_country, :headcount_by_department, :hires_by_year)

    def initialize(population)
      @relation = population.relation
    end

    def call
      Result.new(
        headcount: @relation.count,
        countries_count: @relation.distinct.count(:country_code),
        currencies: counts("current_comp.currency").map { |currency, n| { currency:, headcount: n } },
        headcount_by_country: counts("employees.country_code").map { |code, n| { country_code: code, headcount: n } },
        headcount_by_department: counts("employees.department").map { |name, n| { department: name, headcount: n } },
        hires_by_year: @relation.group(Arel.sql("EXTRACT(YEAR FROM employees.hire_date)::int")).count
                                .sort.map { |year, n| { year:, headcount: n } }
      )
    end

    private

    # Largest first, ties alphabetical, so the order is stable.
    def counts(column)
      @relation.group(column).count.sort_by { |key, n| [ -n, key ] }
    end
  end
end

module Insights
  # Who the dashboard describes: active employees with their current salary, narrowed by the
  # dashboard filters (one or several values each: OR within a filter, AND across filters).
  # Every insights query starts from this, so all widgets agree.
  class Population
    FILTERS = %i[country department job_title].freeze
    COLUMNS = {
      country: "employees.country_code",
      department: "employees.department",
      job_title: "employees.job_title"
    }.freeze

    def initialize(filters = {})
      @filters = filters.to_h.symbolize_keys.slice(*FILTERS)
                        .transform_values { |value| Array(value).compact_blank.uniq.presence }.compact
    end

    def relation
      scope = Employee.active.joins(Employees::DirectoryQuery::CURRENT_COMPENSATION_JOIN)
      @filters.reduce(scope) { |current, (key, value)| current.where(COLUMNS.fetch(key) => value) }
    end

    # One row per employee: the grouping columns plus the current amount and currency.
    def rows_sql
      relation.select(
        "employees.country_code AS country", "employees.department AS department",
        "employees.job_title AS job_title", "current_comp.amount AS amount", "current_comp.currency AS currency"
      ).to_sql
    end
  end
end

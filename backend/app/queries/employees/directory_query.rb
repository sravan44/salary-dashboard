module Employees
  # Search, filter, sort and paginate the employee directory entirely in SQL.
  # Every parameter is validated; problems are collected and raised together as InvalidParams.
  class DirectoryQuery
    class InvalidParams < StandardError
      attr_reader :details

      def initialize(details)
        @details = details
        super("Invalid directory parameters")
      end
    end

    Result = Data.define(:records, :page, :per_page, :total) do
      def total_pages = (total.to_f / per_page).ceil
    end

    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100
    MAX_QUERY_LENGTH = 100
    SORTS = {
      "full_name" => "employees.full_name",
      "employee_number" => "employees.employee_number",
      "hire_date" => "employees.hire_date",
      "salary" => "current_comp.amount"
    }.freeze
    CURRENT_COMPENSATION_JOIN = <<~SQL.squish.freeze
      LEFT JOIN compensations current_comp
        ON current_comp.employee_id = employees.id AND current_comp.effective_to IS NULL
    SQL

    def initialize(params)
      @params = params.to_h.symbolize_keys
      @errors = Hash.new { |hash, key| hash[key] = [] }
    end

    def call
      options = parse
      raise InvalidParams, @errors.to_h if @errors.any?

      scope = filtered_scope(options)
      total = scope.count
      records = scope.select("employees.*", "current_comp.amount AS current_amount", "current_comp.currency AS current_currency")
                     .order(Arel.sql("#{options[:sort_column]} #{options[:sort_direction]}, employees.id ASC"))
                     .limit(options[:per_page]).offset((options[:page] - 1) * options[:per_page])
      Result.new(records: records.to_a, page: options[:page], per_page: options[:per_page], total: total)
    end

    private

    def parse
      {
        q: parse_query,
        country: parse_choice(:country, Acme::Reference.country_codes),
        department: parse_choice(:department, Acme::Reference.departments),
        status: parse_choice(:status, Employee.statuses.keys),
        currency: parse_choice(:currency, Acme::Reference.currencies),
        job_title: present(:job_title),
        min_salary: parse_amount(:min_salary),
        max_salary: parse_amount(:max_salary),
        page: parse_integer(:page, default: 1, min: 1),
        per_page: parse_integer(:per_page, default: DEFAULT_PER_PAGE, min: 1, max: MAX_PER_PAGE)
      }.tap do |options|
        check_salary_range(options)
        parse_sort(options)
      end
    end

    def filtered_scope(options)
      scope = Employee.joins(CURRENT_COMPENSATION_JOIN)
      if options[:q]
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(options[:q])}%"
        scope = scope.where("employees.full_name ILIKE :p OR employees.employee_number ILIKE :p OR employees.email ILIKE :p", p: pattern)
      end
      scope = scope.where(country_code: options[:country]) if options[:country]
      scope = scope.where(department: options[:department]) if options[:department]
      scope = scope.where(job_title: options[:job_title]) if options[:job_title]
      scope = scope.where(status: options[:status]) if options[:status]
      scope = scope.where(current_comp: { currency: options[:currency] }) if options[:currency]
      scope = scope.where("current_comp.amount >= ?", options[:min_salary]) if options[:min_salary]
      scope = scope.where("current_comp.amount <= ?", options[:max_salary]) if options[:max_salary]
      scope
    end

    def present(key)
      @params[key].to_s.strip.presence
    end

    def parse_query
      query = present(:q)
      @errors[:q] << "must be at most #{MAX_QUERY_LENGTH} characters" if query && query.length > MAX_QUERY_LENGTH
      query
    end

    def parse_choice(key, allowed)
      value = present(key)
      @errors[key] << "must be one of: #{allowed.join(', ')}" if value && !allowed.include?(value)
      value
    end

    def parse_amount(key)
      value = present(key)
      return nil unless value

      amount = BigDecimal(value, exception: false)
      @errors[key] << "must be a number greater than or equal to 0" if amount.nil? || amount.negative?
      amount
    end

    def parse_integer(key, default:, min:, max: nil)
      value = present(key)
      return default unless value

      number = Integer(value, exception: false)
      return number if number && number >= min && (max.nil? || number <= max)

      @errors[key] << (max ? "must be an integer from #{min} to #{max}" : "must be an integer of at least #{min}")
      default
    end

    def check_salary_range(options)
      if (options[:min_salary] || options[:max_salary]) && options[:currency].nil?
        @errors[:currency] << "is required when filtering by salary"
      end
      min, max = options.values_at(:min_salary, :max_salary)
      return if min.nil? || max.nil? || @errors.key?(:min_salary) || @errors.key?(:max_salary)

      @errors[:max_salary] << "must be greater than or equal to min_salary" if max < min
    end

    def parse_sort(options)
      raw = present(:sort) || "full_name"
      field = raw.delete_prefix("-")
      options[:sort_direction] = raw.start_with?("-") ? "DESC" : "ASC"
      options[:sort_column] = SORTS.fetch(field) do
        @errors[:sort] << "must be one of: #{SORTS.keys.flat_map { |k| [ k, "-#{k}" ] }.join(', ')}"
        SORTS["full_name"]
      end
      @errors[:sort] << "by salary requires a currency filter" if field == "salary" && options[:currency].nil?
    end
  end
end

module Seeds
  # Generates a deterministic, synthetic workforce with salary history.
  #
  # - Same random_seed => identical data (no clock, no global RNG, no Faker).
  # - Re-running REPLACES all employees and compensations in one transaction, so it never duplicates.
  # - Salaries are plausible bands per country x level, in local currency. They are NOT real market data.
  # - Every salary record has a reason (first = hire, later = annual_review / market_adjustment), and every
  #   seeded row gets a 'create' audit Version attributed to "seed". Bulk inserts skip callbacks, so the
  #   versions are written here explicitly.
  class EmployeeSeeder
    AS_OF = Date.new(2026, 10, 1)        # fixed "today" for the dataset
    EARLIEST_HIRE = Date.new(2014, 1, 1)
    BATCH_SIZE = 1_000
    TERMINATED_SHARE = 0.08
    MARKET_ADJUSTMENT_SHARE = 0.15
    ACTOR = "seed"

    COUNTRY_WEIGHTS = { "US" => 30, "IN" => 25, "GB" => 12, "DE" => 10, "FR" => 7, "CA" => 7, "AU" => 5, "SG" => 4 }.freeze

    # Level-0 annual base salary in each country's own currency.
    BASE_SALARY = { "US" => 70_000, "IN" => 900_000, "GB" => 42_000, "DE" => 50_000,
                    "FR" => 42_000, "CA" => 65_000, "AU" => 75_000, "SG" => 60_000 }.freeze

    DEPARTMENTS = {
      "Engineering" => { weight: 30, multiplier: 1.15,
                         titles: [ "Associate Software Engineer", "Software Engineer", "Senior Software Engineer", "Staff Engineer", "Engineering Manager" ] },
      "Product" => { weight: 8, multiplier: 1.10,
                     titles: [ "Associate Product Manager", "Product Manager", "Senior Product Manager", "Principal Product Manager", "Director of Product" ] },
      "Sales" => { weight: 18, multiplier: 1.00,
                   titles: [ "Sales Development Rep", "Account Executive", "Senior Account Executive", "Sales Lead", "Sales Director" ] },
      "Marketing" => { weight: 8, multiplier: 0.95,
                       titles: [ "Marketing Associate", "Marketing Specialist", "Senior Marketing Specialist", "Marketing Lead", "Head of Marketing" ] },
      "Finance" => { weight: 7, multiplier: 1.00,
                     titles: [ "Finance Associate", "Financial Analyst", "Senior Financial Analyst", "Finance Lead", "Finance Director" ] },
      "People" => { weight: 6, multiplier: 0.90,
                    titles: [ "People Associate", "HR Generalist", "Senior HR Business Partner", "People Lead", "Head of People" ] },
      "Operations" => { weight: 10, multiplier: 0.90,
                        titles: [ "Operations Associate", "Operations Analyst", "Senior Operations Analyst", "Operations Lead", "Operations Director" ] },
      "Customer Support" => { weight: 13, multiplier: 0.80,
                              titles: [ "Support Associate", "Support Specialist", "Senior Support Specialist", "Support Lead", "Support Manager" ] }
    }.freeze

    LEVEL_WEIGHTS = [ 25, 35, 25, 10, 5 ].freeze
    LEVEL_MULTIPLIERS = [ 1.0, 1.35, 1.8, 2.4, 2.6 ].freeze

    FIRST_NAMES = %w[
      Aarav Asha Priya Rohan Ananya Vikram Meera Arjun Kavya Ishaan
      James Olivia Liam Emma Noah Ava Ethan Sophia Lucas Mia
      Lena Felix Hannah Jonas Clara Louis Chloe Hugo Camille Jules
      Wei Mei Ken Yuki Sara Omar Leila Daniel Grace Samuel
    ].freeze

    LAST_NAMES = %w[
      Sharma Patel Rao Iyer Gupta Nair Reddy Das Mehta Kapoor
      Smith Johnson Brown Taylor Wilson Davies Evans Thomas Clarke Walker
      Muller Schmidt Fischer Weber Becker Martin Bernard Dubois Moreau Laurent
      Tan Lim Chen Wong Ng Kumar Singh Nguyen Brown Lee
    ].freeze

    def initialize(count:, random_seed: 42)
      @count = count
      @rng = Random.new(random_seed)
    end

    def call
      employees, histories = build_rows

      ActiveRecord::Base.transaction do
        Version.where(item_type: %w[Employee Compensation]).delete_all
        Compensation.delete_all
        Employee.delete_all
        ids = insert_employees(employees)
        insert_compensations(histories, ids)
      end

      { employees: Employee.count, compensations: Compensation.count,
        current_compensations: Compensation.current.count, versions: Version.count }
    end

    private

    attr_reader :rng

    def build_rows
      employees = []
      histories = {}

      (1..@count).each do |n|
        number = format("EMP-%06d", n)
        employee = build_employee(number)
        employees << employee.except(:level)
        histories[number] = build_history(employee)
      end

      [ employees, histories ]
    end

    def build_employee(number)
      first = FIRST_NAMES[rng.rand(FIRST_NAMES.size)]
      last = LAST_NAMES[rng.rand(LAST_NAMES.size)]
      department = weighted_pick(DEPARTMENTS.transform_values { |d| d[:weight] })
      level = weighted_index(LEVEL_WEIGHTS)

      {
        employee_number: number,
        full_name: "#{first} #{last}",
        email: "#{first}.#{last}.#{number.delete_prefix('EMP-')}@acme.example".downcase,
        country_code: weighted_pick(COUNTRY_WEIGHTS),
        department: department,
        job_title: DEPARTMENTS.dig(department, :titles, level),
        status: rng.rand < TERMINATED_SHARE ? "terminated" : "active",
        hire_date: EARLIEST_HIRE + rng.rand(0..(AS_OF - EARLIEST_HIRE).to_i),
        level: level
      }
    end

    # Oldest first. Each record ends the day before the next begins; the last one is current.
    def build_history(employee)
      currency = Acme::Reference.currency_for(employee[:country_code])
      span_days = (AS_OF - employee[:hire_date]).to_i
      raises = [ (span_days / 365.0 / 1.5).floor, 3 ].min
      starts = [ employee[:hire_date] ] + (1..raises).map { |i| employee[:hire_date] + (span_days * i / (raises + 1)) }
      amounts = amounts_oldest_first(current_amount(employee), starts.size)

      starts.each_with_index.map do |start, i|
        { amount: amounts[i], currency: currency, effective_from: start, effective_to: starts[i + 1]&.prev_day,
          reason: i.zero? ? "hire" : raise_reason, revised_by: ACTOR }
      end
    end

    def current_amount(employee)
      base = BASE_SALARY.fetch(employee[:country_code])
      multiplier = DEPARTMENTS.dig(employee[:department], :multiplier) * LEVEL_MULTIPLIERS[employee[:level]]
      noise = 0.85 + (rng.rand * 0.30)
      base * multiplier * noise
    end

    # Walk backwards from the current salary, undoing a 3-12% raise each step.
    def amounts_oldest_first(current, size)
      amounts = [ round_to_hundred(current) ]
      (size - 1).times { amounts.unshift(round_to_hundred(amounts.first / (1.03 + (rng.rand * 0.09)))) }
      amounts
    end

    def raise_reason = rng.rand < MARKET_ADJUSTMENT_SHARE ? "market_adjustment" : "annual_review"

    # BigDecimal#round(-2) returns an Integer; keep it a BigDecimal so amounts stay exact decimals everywhere.
    def round_to_hundred(value) = BigDecimal(value.to_s).round(-2).to_d

    def weighted_pick(weights)
      weights.keys[weighted_index(weights.values)]
    end

    def weighted_index(weights)
      target = rng.rand(weights.sum)
      weights.each_with_index do |weight, index|
        return index if target < weight

        target -= weight
      end
    end

    def insert_employees(rows)
      rows.each_slice(BATCH_SIZE).flat_map do |batch|
        ids = Employee.insert_all!(batch, returning: %w[id]).rows.flatten
        insert_versions("Employee", batch, ids)
        batch.map { |row| row[:employee_number] }.zip(ids)
      end.to_h
    end

    def insert_compensations(histories, ids)
      rows = histories.flat_map { |number, history| history.map { |row| row.merge(employee_id: ids.fetch(number)) } }
      rows.each_slice(BATCH_SIZE) do |batch|
        new_ids = Compensation.insert_all!(batch, returning: %w[id]).rows.flatten
        insert_versions("Compensation", batch, new_ids)
      end
    end

    def insert_versions(item_type, rows, ids)
      versions = rows.zip(ids).map do |row, id|
        changes = Versioned.changes_for(row.stringify_keys.transform_values { |value| [ nil, value ] })
        { item_type: item_type, item_id: id, event: "create", object_changes: changes, whodunnit: ACTOR }
      end
      Version.insert_all!(versions)
    end
  end
end

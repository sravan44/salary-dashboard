FactoryBot.define do
  factory :employee do
    sequence(:employee_number) { |n| format("EMP-%06d", n) }
    sequence(:full_name) { |n| "Test Person #{n}" }
    sequence(:email) { |n| "person#{n}@acme.example" }
    country_code { "US" }
    department { "Engineering" }
    job_title { "Software Engineer" }
    status { "active" }
    hire_date { Date.new(2020, 1, 15) }
  end

  factory :compensation do
    employee
    amount { "120000.00" }
    currency { "USD" }
    effective_from { Date.new(2020, 1, 15) }
    effective_to { nil }
    reason { "hire" }
  end

  factory :user do
    sequence(:email) { |n| "user#{n}@acme.example" }
    password { "correct horse battery" }
    roles { [ "viewer" ] }
  end
end

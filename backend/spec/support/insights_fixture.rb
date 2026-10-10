# A small workforce whose pay statistics are worked out by hand (docs/analytics-definitions.md).
#
#   no.  country dept         title              status      current salary   (history)
#   001  US      Engineering  Software Engineer  active      120,000 USD
#   002  IN      Engineering  Software Engineer  active    2,400,000 INR
#   003  DE      People       HR Generalist      active       72,000 EUR
#   004  IN      Finance      Financial Analyst  terminated 1,800,000 INR      excluded: not active
#   005  US      Engineering  Software Engineer  active      100,000 USD
#   006  FR      People       HR Generalist      active       65,000 EUR      same currency, other country
#   007  US      Sales        Account Executive  active       90,000 USD      was 80,000 until 2023-12-31
module InsightsFixture
  def create_insights_fixture
    hire("001", "US", "Engineering", "Software Engineer", "120000", "USD")
    hire("002", "IN", "Engineering", "Software Engineer", "2400000", "INR")
    hire("003", "DE", "People", "HR Generalist", "72000", "EUR")
    hire("004", "IN", "Finance", "Financial Analyst", "1800000", "INR", status: "terminated")
    hire("005", "US", "Engineering", "Software Engineer", "100000", "USD")
    hire("006", "FR", "People", "HR Generalist", "65000", "EUR")
    raised = hire("007", "US", "Sales", "Account Executive", "80000", "USD")
    raised.compensations.sole.update!(effective_to: Date.new(2023, 12, 31))
    FactoryBot.create(:compensation, employee: raised, amount: "90000", currency: "USD",
                                     effective_from: Date.new(2024, 1, 1), reason: "annual_review")
  end

  private

  def hire(number, country, department, title, amount, currency, status: "active")
    employee = FactoryBot.create(:employee, employee_number: "EMP-000#{number}", country_code: country,
                                            department:, job_title: title, status:, hire_date: Date.new(2020, 1, 1))
    FactoryBot.create(:compensation, employee:, amount:, currency:, effective_from: Date.new(2020, 1, 1))
    employee
  end
end

RSpec.configure { |config| config.include InsightsFixture }

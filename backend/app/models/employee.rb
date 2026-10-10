class Employee < ApplicationRecord
  include Versioned

  EMPLOYEE_NUMBER_FORMAT = /\AEMP-\d{6}\z/

  has_many :compensations, dependent: :restrict_with_exception
  has_one :current_compensation, -> { current }, class_name: "Compensation", inverse_of: :employee

  enum :status, { active: "active", terminated: "terminated" }, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :employee_number, presence: true, uniqueness: true, format: { with: EMPLOYEE_NUMBER_FORMAT, allow_blank: true }
  validates :full_name, presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :country_code, presence: true, inclusion: { in: Acme::Reference.country_codes, allow_blank: true }
  validates :department, presence: true, inclusion: { in: Acme::Reference.departments, allow_blank: true }
  validates :job_title, presence: true, length: { maximum: 120 }
  validates :hire_date, presence: true
end

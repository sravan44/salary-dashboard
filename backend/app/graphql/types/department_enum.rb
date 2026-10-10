module Types
  class DepartmentEnum < BaseEnum
    graphql_name "Department"
    description "Department; the value is the department name (e.g. CUSTOMER_SUPPORT is \"Customer Support\")"
    Acme::Reference.departments.each { |name| value name.upcase.tr(" ", "_"), name, value: name }
  end
end

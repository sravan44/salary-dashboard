module Types
  class PayGroupByEnum < BaseEnum
    graphql_name "PayGroupBy"
    description "How to group salary statistics"
    value "COUNTRY", value: :country
    value "DEPARTMENT", value: :department
    value "JOB_TITLE", value: :job_title
  end
end

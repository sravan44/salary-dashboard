module Types
  class SalaryBucketType < BaseObject
    graphql_name "SalaryBucket"
    field :from, String, null: false
    field :to, String, null: false
    field :count, Integer, null: false
  end
end

module Types
  class DepartmentHeadcountType < BaseObject
    graphql_name "DepartmentHeadcount"
    field :department, String, null: false
    field :headcount, Integer, null: false
  end
end

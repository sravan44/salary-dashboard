module Types
  class YearHeadcountType < BaseObject
    graphql_name "YearHeadcount"
    field :year, Integer, null: false
    field :headcount, Integer, null: false
  end
end

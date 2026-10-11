module Types
  class ConvertedPayStatType < BaseObject
    graphql_name "ConvertedPayStat"
    description "Pay statistics in the reporting currency (each salary converted first, then aggregated)"
    field :group, String, null: false
    field :headcount, Integer, null: false
    field :min, String, null: false
    field :max, String, null: false
    field :avg, String, null: false
    field :median, String, null: false
  end
end

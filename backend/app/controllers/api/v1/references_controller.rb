module Api
  module V1
    # Values for the UI's filter dropdowns.
    class ReferencesController < BaseController
      def show
        render json: {
          data: {
            countries: Acme::Reference::COUNTRIES.map { |code, c| { code: code, name: c[:name], currency: c[:currency] } },
            currencies: Acme::Reference.currencies,
            departments: Acme::Reference.departments,
            statuses: Employee.statuses.keys,
            job_titles: Employee.distinct.order(:job_title).pluck(:job_title)
          }
        }
      end
    end
  end
end

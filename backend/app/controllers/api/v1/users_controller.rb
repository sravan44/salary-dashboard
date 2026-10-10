module Api
  module V1
    # User accounts and roles (Admin only). Email and password are set when the account is created;
    # afterwards only the roles change here.
    class UsersController < BaseController
      require_permission :manage_users

      def index
        render json: { data: User.order(:email).map { |user| UserSerializer.summary(user) } }
      end

      def create
        user = User.new(params.require(:user).permit(:email, :password, roles: []))
        return render_validation_errors(user.errors.to_hash.transform_keys(&:to_s)) unless user.save

        render json: { data: UserSerializer.summary(user) }, status: :created
      end

      def update
        user = User.find(params[:id])
        roles = params.require(:user).permit(roles: []).fetch(:roles, [])
        result = Users::UpdateRoles.call(user, roles:, by: Current.user)
        return render_validation_errors(result.errors) unless result.success?

        render json: { data: UserSerializer.summary(result.user) }
      end
    end
  end
end

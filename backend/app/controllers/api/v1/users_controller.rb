module Api
  module V1
    # User accounts, roles and passwords (Admin only). A new account gets a password typed by the Admin, or none yet:
    # the Admin then sends password links to the chosen users when ready (a set-password link to anyone without a
    # password, a reset link to anyone with one). Admins can also set a password directly.
    class UsersController < BaseController
      require_permission :manage_users

      def index
        render json: { data: User.order(:email).map { |user| UserSerializer.summary(user) } }
      end

      def create
        attributes = params.require(:user).permit(:email, :password, roles: [])
        invite = attributes[:password].blank?
        # An invited account holds a random password nobody knows until the set-password link is used.
        attributes[:password] = SecureRandom.base58(32) if invite
        user = User.new(attributes.merge(password_changed_at: (Time.current unless invite)))
        return render_validation_errors(user.errors.to_hash.transform_keys(&:to_s)) unless user.save

        render json: { data: UserSerializer.summary(user) }, status: :created
      end

      def set_password
        user = User.find(params[:id])
        result = Users::SetPassword.call(user, password: params[:password], password_confirmation: params[:password_confirmation])
        return render_validation_errors(result.errors) unless result.success?

        render json: { data: UserSerializer.summary(result.user) }
      end

      MAX_LINKS = 50

      def send_password_links
        ids = Array(params[:user_ids]).map(&:to_i).uniq
        unless ids.size.between?(1, MAX_LINKS)
          return render_validation_errors("user_ids" => [ "choose between 1 and #{MAX_LINKS} users" ])
        end

        users = User.where(id: ids).to_a
        raise ActiveRecord::RecordNotFound if users.size != ids.size

        users.each { |user| (user.password_set? ? UserMailer.password_reset(user) : UserMailer.invitation(user)).deliver_later }
        render json: { data: { sent: users.size } }, status: :accepted
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

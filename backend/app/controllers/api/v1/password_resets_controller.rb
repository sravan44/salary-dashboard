module Api
  module V1
    # Signed out. POST: "Forgot password?" emails a reset link. PATCH: a reset or set-password link sets a new
    # password. The POST answers the same whether or not the address has an account, so it reveals nothing.
    class PasswordResetsController < BaseController
      RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
      SENT = "If an account exists for that email, we've sent a link to reset the password.".freeze

      allow_signed_out
      rate_limit to: 5, within: 15.minutes, only: :create, store: RATE_LIMIT_STORE, name: "request-link",
                 with: -> { render_error(:too_many_requests, "too_many_attempts", "Too many requests. Try again in a few minutes.") }
      rate_limit to: 10, within: 15.minutes, only: :update, store: RATE_LIMIT_STORE, name: "use-link",
                 with: -> { render_error(:too_many_requests, "too_many_attempts", "Too many attempts. Try again in a few minutes.") }

      def create
        user = User.find_by(email: params.require(:email).to_s.strip.downcase)
        UserMailer.password_reset(user).deliver_later if user
        render json: { data: { message: SENT } }, status: :accepted
      end

      def update
        token = params.require(:token).to_s
        user = User.find_by_password_reset_token(token) || User.find_by_token_for(:password_setup, token)
        unless user
          return render_error(:unprocessable_content, "invalid_token", "This link is invalid or has expired. Ask for a new one.")
        end

        Current.actor = "#{user.email} (link)"
        result = Users::SetPassword.call(user, password: params[:password], password_confirmation: params[:password_confirmation])
        return render_validation_errors(result.errors) unless result.success?

        head :no_content
      end
    end
  end
end

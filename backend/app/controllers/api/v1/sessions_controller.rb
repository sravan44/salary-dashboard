module Api
  module V1
    # Sign in (POST), who am I (GET), sign out (DELETE).
    class SessionsController < BaseController
      # Per-process store: enough for one app container. A shared cache would be needed for several.
      RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

      allow_signed_out only: :create
      rate_limit to: 10, within: 3.minutes, only: :create, store: RATE_LIMIT_STORE,
                 with: -> { render_error(:too_many_requests, "too_many_attempts", "Too many sign-in attempts. Try again in a few minutes.") }

      def show
        render json: { data: UserSerializer.session(Current.user) }
      end

      def create
        # authenticate_by takes the same time whether or not the email exists.
        user = User.authenticate_by(email: params.require(:email).to_s.strip.downcase, password: params.require(:password).to_s)
        return render_error(:unauthorized, "invalid_credentials", "Email or password is incorrect") unless user

        start_session(user)
        render json: { data: UserSerializer.session(user) }, status: :created
      end

      def destroy
        end_session
        head :no_content
      end
    end
  end
end

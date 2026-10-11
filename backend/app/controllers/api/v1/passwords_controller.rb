module Api
  module V1
    # The signed-in user changes their own password. This session stays signed in; all others end.
    class PasswordsController < BaseController
      def update
        unless Current.user.authenticate(params[:current_password].to_s)
          return render_validation_errors("current_password" => [ "is incorrect" ])
        end

        result = Users::SetPassword.call(Current.user, password: params[:password], password_confirmation: params[:password_confirmation],
                                                       keep_session: Current.session)
        return render_validation_errors(result.errors) unless result.success?

        head :no_content
      end
    end
  end
end

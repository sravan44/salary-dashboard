module Users
  # Sets a user's password, whoever asks: the user (current password checked by the caller), a reset or
  # set-password link, or an Admin. Stamps when it changed, which is what the audit log records (never the
  # password or its digest), and signs the user out of every other session.
  class SetPassword
    Result = Data.define(:user, :errors) do
      def success? = errors.empty?
    end

    def self.call(user, password:, password_confirmation: nil, keep_session: nil) =
      new(user, password:, password_confirmation:, keep_session:).call

    def initialize(user, password:, password_confirmation:, keep_session:)
      @user = user
      @password = password.to_s
      @password_confirmation = password_confirmation
      @keep_session = keep_session
    end

    def call
      return failure("password" => [ "can't be blank" ]) if @password.empty?

      User.transaction do
        @user.assign_attributes(password: @password, password_confirmation: @password_confirmation,
                                password_changed_at: Time.current)
        return failure(@user.errors.to_hash.transform_keys(&:to_s)) unless @user.save

        @user.sessions.where.not(id: @keep_session&.id).delete_all
      end
      Result.new(user: @user, errors: {})
    end

    private

    def failure(errors)
      @user.restore_attributes(%i[password_digest password_changed_at])
      Result.new(user: @user, errors:)
    end
  end
end

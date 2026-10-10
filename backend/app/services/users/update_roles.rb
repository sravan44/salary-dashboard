module Users
  # Replaces a user's roles, guarding against locking everyone out: an admin cannot remove their own
  # Admin role, and the last admin always keeps it. Admin rows are locked while checking, so two
  # admins demoting each other at the same moment cannot both succeed.
  class UpdateRoles
    Result = Data.define(:user, :errors) do
      def success? = errors.empty?
    end

    def self.call(user, roles:, by:) = new(user, roles:, by:).call

    def initialize(user, roles:, by:)
      @user = user
      @roles = Array(roles)
      @by = by
    end

    def call
      User.transaction do
        admins = User.where("'admin' = ANY(roles)").lock.pluck(:id)
        if losing_admin?(admins)
          return failure("you cannot remove your own Admin role") if @user.id == @by.id
          return failure("at least one Admin must remain") if admins == [ @user.id ]
        end

        @user.roles = @roles
        return Result.new(user: @user, errors: @user.errors.to_hash.transform_keys(&:to_s)) unless @user.save
      end
      Result.new(user: @user, errors: {})
    end

    private

    def losing_admin?(admins) = admins.include?(@user.id) && @roles.map(&:to_s).exclude?("admin")

    def failure(message) = Result.new(user: @user, errors: { "roles" => [ message ] })
  end
end

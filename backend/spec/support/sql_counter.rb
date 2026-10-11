# Counts the SQL statements a block issues (ignoring schema lookups and transaction savepoints),
# so specs can pin the number of queries a read path makes: no N+1, no repeated passes.
module SqlCounter
  def sql_statements
    statements = []
    callback = lambda do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:sql] =~ /\A\s*(SAVEPOINT|RELEASE|ROLLBACK|BEGIN|COMMIT)/

      statements << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { ActiveRecord::Base.uncached { yield } }
    statements
  end
end

RSpec.configure { |config| config.include SqlCounter }

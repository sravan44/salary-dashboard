# Loads deploy/deploy.env (KEY=VALUE lines, # comments) into ENV without overriding variables already set in the
# shell. Plain Ruby, so the deploy tooling needs no extra gem.
module DeployEnv
  module_function

  def load(path)
    return unless File.exist?(path)

    File.foreach(path, encoding: "UTF-8") do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, value = line.split("=", 2)
      next if value.nil? || value.strip.empty? || ENV.key?(key.strip)

      ENV[key.strip] = value.strip.delete_prefix('"').delete_suffix('"')
    end
  end

  def fetch(key)
    ENV.fetch(key) { abort "Set #{key} in deploy/deploy.env (copy deploy/deploy.env.example) or in your shell" }
  end
end

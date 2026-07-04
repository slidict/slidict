# frozen_string_literal: true

require "slidict"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Temporarily sets the given ENV vars for the duration of the block, restoring
# (or removing) the previous values afterwards.
def with_env(vars)
  original = vars.each_key.to_h { |key| [key, ENV[key]] }
  vars.each { |key, value| ENV[key] = value }
  yield
ensure
  original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
end

# frozen_string_literal: true

require "kanji/translator"

RSpec.configure do |config|
  require "webmock/rspec"
  WebMock.disable_net_connect!(allow_localhost: true)

  begin
    require "vcr"
    VCR.configure do |c|
      c.cassette_library_dir = "spec/cassettes"
      c.hook_into :webmock
      # Do not allow new HTTP connections during tests
      c.default_cassette_options = { record: :none }
    end
  rescue LoadError
    warn "VCR not available; proceeding without it"
  end
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

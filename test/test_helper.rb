ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Plaintext for the api_tokens fixtures. The DB only stores their digest, so
    # tests reference these to build "Authorization: Bearer <token>" headers.
    RAW_API_TOKENS = { macos: "ghr_test_macos_0001", cli: "ghr_test_cli_0002" }.freeze

    # Add more helper methods to be used by all tests here...
  end
end

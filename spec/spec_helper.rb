# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'bundler/setup'

$LOADED_FEATURES << 'legion/extensions/actors/every'

module Legion
  module Extensions
    module Helpers
      module Lex; end
    end

    module Actors
      class Every
        def initialize(**); end
      end

      class Once
        def initialize(**); end
      end
    end
  end
end

require 'legion/extensions/identity/ldap'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

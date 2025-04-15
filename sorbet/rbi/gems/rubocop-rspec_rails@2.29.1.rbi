# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `rubocop-rspec_rails` gem.
# Please instead update this file by running `bin/tapioca gem rubocop-rspec_rails`.


# FIXME: This is a workaround for the following issue:
# https://github.com/rubocop/rubocop-rspec_rails/issues/8
#
# source://rubocop-rspec_rails//lib/rubocop/rspec_rails/version.rb#3
module RuboCop; end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/avoid_setup_hook.rb#4
module RuboCop::Cop; end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/avoid_setup_hook.rb#5
module RuboCop::Cop::RSpecRails; end

# Checks that tests use RSpec `before` hook over Rails `setup` method.
#
# @example
#   # bad
#   setup do
#   allow(foo).to receive(:bar)
#   end
#
#   # good
#   before do
#   allow(foo).to receive(:bar)
#   end
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/avoid_setup_hook.rb#19
class RuboCop::Cop::RSpecRails::AvoidSetupHook < ::RuboCop::Cop::Base
  extend ::RuboCop::Cop::AutoCorrector

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/avoid_setup_hook.rb#31
  def on_block(node); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/avoid_setup_hook.rb#25
  def setup_call(param0 = T.unsafe(nil)); end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/avoid_setup_hook.rb#22
RuboCop::Cop::RSpecRails::AvoidSetupHook::MSG = T.let(T.unsafe(nil), String)

# Checks that tests use `have_http_status` instead of equality matchers.
#
# @example ResponseMethods: ['response', 'last_response'] (default)
#   # bad
#   expect(response.status).to be(200)
#   expect(last_response.code).to eq("200")
#
#   # good
#   expect(response).to have_http_status(200)
#   expect(last_response).to have_http_status(200)
# @example ResponseMethods: ['foo_response']
#   # bad
#   expect(foo_response.status).to be(200)
#
#   # good
#   expect(foo_response).to have_http_status(200)
#
#   # also good
#   expect(response).to have_http_status(200)
#   expect(last_response).to have_http_status(200)
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#28
class RuboCop::Cop::RSpecRails::HaveHttpStatus < ::RuboCop::Cop::Base
  extend ::RuboCop::Cop::AutoCorrector

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#39
  def match_status(param0 = T.unsafe(nil)); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#49
  def on_send(node); end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#71
  def response_methods; end

  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#67
  def response_methods?(name); end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#31
RuboCop::Cop::RSpecRails::HaveHttpStatus::MSG = T.let(T.unsafe(nil), String)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#36
RuboCop::Cop::RSpecRails::HaveHttpStatus::RESTRICT_ON_SEND = T.let(T.unsafe(nil), Set)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/have_http_status.rb#35
RuboCop::Cop::RSpecRails::HaveHttpStatus::RUNNERS = T.let(T.unsafe(nil), Set)

# Enforces use of symbolic or numeric value to describe HTTP status.
#
# This cop inspects only `have_http_status` calls.
# So, this cop does not check if a method starting with `be_*` is used
# when setting for `EnforcedStyle: symbolic` or
# `EnforcedStyle: numeric`.
#
# @example `EnforcedStyle: symbolic` (default)
#   # bad
#   it { is_expected.to have_http_status 200 }
#   it { is_expected.to have_http_status 404 }
#   it { is_expected.to have_http_status "403" }
#
#   # good
#   it { is_expected.to have_http_status :ok }
#   it { is_expected.to have_http_status :not_found }
#   it { is_expected.to have_http_status :forbidden }
#   it { is_expected.to have_http_status :success }
#   it { is_expected.to have_http_status :error }
# @example `EnforcedStyle: numeric`
#   # bad
#   it { is_expected.to have_http_status :ok }
#   it { is_expected.to have_http_status :not_found }
#   it { is_expected.to have_http_status "forbidden" }
#
#   # good
#   it { is_expected.to have_http_status 200 }
#   it { is_expected.to have_http_status 404 }
#   it { is_expected.to have_http_status 403 }
#   it { is_expected.to have_http_status :success }
#   it { is_expected.to have_http_status :error }
# @example `EnforcedStyle: be_status`
#   # bad
#   it { is_expected.to have_http_status :ok }
#   it { is_expected.to have_http_status :not_found }
#   it { is_expected.to have_http_status "forbidden" }
#   it { is_expected.to have_http_status 200 }
#   it { is_expected.to have_http_status 404 }
#   it { is_expected.to have_http_status "403" }
#
#   # good
#   it { is_expected.to be_ok }
#   it { is_expected.to be_not_found }
#   it { is_expected.to have_http_status :success }
#   it { is_expected.to have_http_status :error }
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#60
class RuboCop::Cop::RSpecRails::HttpStatus < ::RuboCop::Cop::Base
  include ::RuboCop::Cop::ConfigurableEnforcedStyle
  extend ::RuboCop::Cop::AutoCorrector

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#66
  def http_status(param0 = T.unsafe(nil)); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#70
  def on_send(node); end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#88
  def checker_class; end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#176
class RuboCop::Cop::RSpecRails::HttpStatus::BeStatusStyleChecker < ::RuboCop::Cop::RSpecRails::HttpStatus::StyleCheckerBase
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#182
  def offense_range; end

  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#177
  def offensive?; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#186
  def prefer; end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#206
  def normalize_str; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#202
  def number; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#198
  def symbol; end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#155
class RuboCop::Cop::RSpecRails::HttpStatus::NumericStyleChecker < ::RuboCop::Cop::RSpecRails::HttpStatus::StyleCheckerBase
  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#156
  def offensive?; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#160
  def prefer; end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#170
  def number; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#166
  def symbol; end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#63
RuboCop::Cop::RSpecRails::HttpStatus::RESTRICT_ON_SEND = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#100
class RuboCop::Cop::RSpecRails::HttpStatus::StyleCheckerBase
  # @return [StyleCheckerBase] a new instance of StyleCheckerBase
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#107
  def initialize(node); end

  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#123
  def allowed_symbol?; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#115
  def current; end

  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#127
  def custom_http_status_code?; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#111
  def message; end

  # Returns the value of attribute node.
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#105
  def node; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#119
  def offense_range; end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#103
RuboCop::Cop::RSpecRails::HttpStatus::StyleCheckerBase::ALLOWED_STATUSES = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#101
RuboCop::Cop::RSpecRails::HttpStatus::StyleCheckerBase::MSG = T.let(T.unsafe(nil), String)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#134
class RuboCop::Cop::RSpecRails::HttpStatus::SymbolicStyleChecker < ::RuboCop::Cop::RSpecRails::HttpStatus::StyleCheckerBase
  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#135
  def offensive?; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#139
  def prefer; end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#149
  def number; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/http_status.rb#145
  def symbol; end
end

# Identifies redundant spec type.
#
# After setting up rspec-rails, you will have enabled
# `config.infer_spec_type_from_file_location!` by default in
# spec/rails_helper.rb. This cop works in conjunction with this config.
# If you disable this config, disable this cop as well.
#
# @example
#   # bad
#   # spec/models/user_spec.rb
#   RSpec.describe User, type: :model do
#   end
#
#   # good
#   # spec/models/user_spec.rb
#   RSpec.describe User do
#   end
#
#   # good
#   # spec/models/user_spec.rb
#   RSpec.describe User, type: :common do
#   end
# @example `Inferences` configuration
#   # .rubocop.yml
#   # RSpecRails/InferredSpecType:
#   #   Inferences:
#   #     services: service
#
#   # bad
#   # spec/services/user_spec.rb
#   RSpec.describe User, type: :service do
#   end
#
#   # good
#   # spec/services/user_spec.rb
#   RSpec.describe User do
#   end
#
#   # good
#   # spec/services/user_spec.rb
#   RSpec.describe User, type: :common do
#   end
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#53
class RuboCop::Cop::RSpecRails::InferredSpecType < ::RuboCop::Cop::RSpec::Base
  extend ::RuboCop::Cop::AutoCorrector

  # @param node [RuboCop::AST::BlockNode]
  # @return [RuboCop::AST::PairNode, nil]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#78
  def describe_with_type(param0 = T.unsafe(nil)); end

  # @param node [RuboCop::AST::BlockNode]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#59
  def on_block(node); end

  # @param node [RuboCop::AST::BlockNode]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#59
  def on_numblock(node); end

  private

  # @param corrector [RuboCop::AST::Corrector]
  # @param node [RuboCop::AST::Node]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#90
  def autocorrect(corrector, node); end

  # @param node [RuboCop::AST::PairNode]
  # @return [RuboCop::AST::Node]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#110
  def detect_removable_node(node); end

  # @return [String]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#119
  def file_path; end

  # @return [Hash]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#137
  def inferences; end

  # @param node [RuboCop::AST::PairNode]
  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#125
  def inferred_type?(node); end

  # @return [Symbol, nil]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#130
  def inferred_type_from_file_path; end

  # @param node [RuboCop::AST::Node]
  # @return [Parser::Source::Range]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#96
  def remove_range(node); end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/inferred_spec_type.rb#56
RuboCop::Cop::RSpecRails::InferredSpecType::MSG = T.let(T.unsafe(nil), String)

# Check if using Minitest-like matchers.
#
# Check the use of minitest-like matchers
# starting with `assert_` or `refute_`.
#
# @example
#   # bad
#   assert_equal(a, b)
#   assert_equal a, b, "must be equal"
#   assert_not_includes a, b
#   refute_equal(a, b)
#   assert_nil a
#   refute_empty(b)
#   assert_true(a)
#   assert_false(a)
#
#   # good
#   expect(b).to eq(a)
#   expect(b).to(eq(a), "must be equal")
#   expect(a).not_to include(b)
#   expect(b).not_to eq(a)
#   expect(a).to eq(nil)
#   expect(a).not_to be_empty
#   expect(a).to be(true)
#   expect(a).to be(false)
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#32
class RuboCop::Cop::RSpecRails::MinitestAssertions < ::RuboCop::Cop::Base
  extend ::RuboCop::Cop::AutoCorrector

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#344
  def message(preferred); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#337
  def on_assertion(node, assertion); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#325
  def on_send(node); end
end

# TODO: replace with `BasicAssertion.subclasses` in Ruby 3.1+
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#317
RuboCop::Cop::RSpecRails::MinitestAssertions::ASSERTION_MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#36
class RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  extend ::RuboCop::AST::NodePattern::Macros

  # @return [BasicAssertion] a new instance of BasicAssertion
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#45
  def initialize(expected, actual, failure_message); end

  # Returns the value of attribute actual.
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#39
  def actual; end

  # @raise [NotImplementedError]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#64
  def assertion; end

  # Returns the value of attribute expected.
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#39
  def expected; end

  # Returns the value of attribute failure_message.
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#39
  def failure_message; end

  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#60
  def negated?(node); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#51
  def replaced(node); end

  class << self
    # @raise [NotImplementedError]
    #
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#41
    def minitest_assertion; end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#253
class RuboCop::Cop::RSpecRails::MinitestAssertions::EmptyAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#269
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#265
    def match(actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#261
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#254
RuboCop::Cop::RSpecRails::MinitestAssertions::EmptyAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#70
class RuboCop::Cop::RSpecRails::MinitestAssertions::EqualAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#86
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#82
    def match(expected, actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#78
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#71
RuboCop::Cop::RSpecRails::MinitestAssertions::EqualAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#295
class RuboCop::Cop::RSpecRails::MinitestAssertions::FalseAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#309
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#305
    def match(actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#301
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#296
RuboCop::Cop::RSpecRails::MinitestAssertions::FalseAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#158
class RuboCop::Cop::RSpecRails::MinitestAssertions::InDeltaAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # @return [InDeltaAssertion] a new instance of InDeltaAssertion
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#174
  def initialize(expected, actual, delta, fail_message); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#180
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#170
    def match(expected, actual, delta, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#166
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#159
RuboCop::Cop::RSpecRails::MinitestAssertions::InDeltaAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#136
class RuboCop::Cop::RSpecRails::MinitestAssertions::IncludesAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#152
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#148
    def match(collection, expected, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#144
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#137
RuboCop::Cop::RSpecRails::MinitestAssertions::IncludesAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#114
class RuboCop::Cop::RSpecRails::MinitestAssertions::InstanceOfAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#130
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#126
    def match(expected, actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#122
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#115
RuboCop::Cop::RSpecRails::MinitestAssertions::InstanceOfAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#92
class RuboCop::Cop::RSpecRails::MinitestAssertions::KindOfAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#108
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#104
    def match(expected, actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#100
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#93
RuboCop::Cop::RSpecRails::MinitestAssertions::KindOfAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#314
RuboCop::Cop::RSpecRails::MinitestAssertions::MSG = T.let(T.unsafe(nil), String)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#210
class RuboCop::Cop::RSpecRails::MinitestAssertions::MatchAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#225
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#221
    def match(matcher, actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#217
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#211
RuboCop::Cop::RSpecRails::MinitestAssertions::MatchAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#231
class RuboCop::Cop::RSpecRails::MinitestAssertions::NilAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#247
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#243
    def match(actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#239
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#232
RuboCop::Cop::RSpecRails::MinitestAssertions::NilAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#186
class RuboCop::Cop::RSpecRails::MinitestAssertions::PredicateAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#204
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#198
    def match(subject, predicate, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#194
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#187
RuboCop::Cop::RSpecRails::MinitestAssertions::PredicateAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#323
RuboCop::Cop::RSpecRails::MinitestAssertions::RESTRICT_ON_SEND = T.let(T.unsafe(nil), Array)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#275
class RuboCop::Cop::RSpecRails::MinitestAssertions::TrueAssertion < ::RuboCop::Cop::RSpecRails::MinitestAssertions::BasicAssertion
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#289
  def assertion; end

  class << self
    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#285
    def match(actual, failure_message); end

    # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#281
    def minitest_assertion(param0 = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/minitest_assertions.rb#276
RuboCop::Cop::RSpecRails::MinitestAssertions::TrueAssertion::MATCHERS = T.let(T.unsafe(nil), Array)

# Enforces use of `be_invalid` or `not_to` for negated be_valid.
#
# @example EnforcedStyle: not_to (default)
#   # bad
#   expect(foo).to be_invalid
#
#   # good
#   expect(foo).not_to be_valid
#
#   # good (with method chain)
#   expect(foo).to be_invalid.and be_odd
# @example EnforcedStyle: be_invalid
#   # bad
#   expect(foo).not_to be_valid
#
#   # good
#   expect(foo).to be_invalid
#
#   # good (with method chain)
#   expect(foo).to be_invalid.or be_even
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#32
class RuboCop::Cop::RSpecRails::NegationBeValid < ::RuboCop::Cop::Base
  include ::RuboCop::Cop::ConfigurableEnforcedStyle
  extend ::RuboCop::Cop::AutoCorrector

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#45
  def be_invalid?(param0 = T.unsafe(nil)); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#40
  def not_to?(param0 = T.unsafe(nil)); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#49
  def on_send(node); end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#74
  def message(_matcher); end

  # @return [Boolean]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#61
  def offense?(node); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#70
  def offense_range(node); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#87
  def replaced_matcher; end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#78
  def replaced_runner; end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#36
RuboCop::Cop::RSpecRails::NegationBeValid::MSG = T.let(T.unsafe(nil), String)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/negation_be_valid.rb#37
RuboCop::Cop::RSpecRails::NegationBeValid::RESTRICT_ON_SEND = T.let(T.unsafe(nil), Array)

# Prefer to travel in `before` rather than `around`.
#
# @example
#   # bad
#   around do |example|
#   freeze_time do
#   example.run
#   end
#   end
#
#   # good
#   before { freeze_time }
#
# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#26
class RuboCop::Cop::RSpecRails::TravelAround < ::RuboCop::Cop::Base
  extend ::RuboCop::Cop::AutoCorrector

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#38
  def extract_run_in_travel(param0 = T.unsafe(nil)); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#47
  def match_around_each?(param0 = T.unsafe(nil)); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#54
  def on_block(node); end

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#54
  def on_numblock(node); end

  private

  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#69
  def autocorrect(corrector, node, run_node, around_node); end

  # @param node [RuboCop::AST::BlockNode]
  # @return [RuboCop::AST::BlockNode, nil]
  #
  # source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#82
  def extract_surrounding_around_block(node); end
end

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#29
RuboCop::Cop::RSpecRails::TravelAround::MSG = T.let(T.unsafe(nil), String)

# source://rubocop-rspec_rails//lib/rubocop/cop/rspec_rails/travel_around.rb#31
RuboCop::Cop::RSpecRails::TravelAround::TRAVEL_METHOD_NAMES = T.let(T.unsafe(nil), Set)

# source://rubocop-rspec_rails//lib/rubocop-rspec_rails.rb#24
class RuboCop::Cop::Registry
  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#51
  def initialize(cops = T.unsafe(nil), options = T.unsafe(nil)); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#232
  def ==(other); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#97
  def contains_cop_matching?(names); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#179
  def cops; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#224
  def cops_for_department(department); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#93
  def department?(name); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#147
  def department_missing?(badge, name); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#72
  def departments; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#193
  def disabled(config); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#67
  def dismiss(cop); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#247
  def each(&block); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#189
  def enabled(config); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#197
  def enabled?(cop, config); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#213
  def enabled_pending_cop?(cop_cfg, config); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#63
  def enlist(cop); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#253
  def find_by_cop_name(cop_name); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#260
  def find_cops_by_directive(directive); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#265
  def freeze; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#184
  def length; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#220
  def names; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#228
  def names_for_department(department); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#49
  def options; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#151
  def print_warning(name, path); end

  # source://rubocop-rspec_rails//lib/rubocop-rspec_rails.rb#26
  def qualified_cop_name(name, path, warn: T.unsafe(nil)); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#166
  def qualify_badge(badge); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#243
  def select(&block); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#236
  def sort!; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#174
  def to_h; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#159
  def unqualified_cop_names; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#78
  def with_department(department); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#84
  def without_department(department); end

  private

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#283
  def clear_enrollment_queue; end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#279
  def initialize_copy(reg); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#312
  def registered?(badge); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#299
  def resolve_badge(given_badge, real_badge, source_path, warn: T.unsafe(nil)); end

  # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#295
  def with(cops); end

  class << self
    # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#22
    def all; end

    # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#274
    def global; end

    # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#44
    def qualified_cop?(name); end

    # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#26
    def qualified_cop_name(name, origin, warn: T.unsafe(nil)); end

    # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#40
    def reset!; end

    # source://rubocop/1.75.1/lib/rubocop/cop/registry.rb#32
    def with_temporary_global(temp_global = T.unsafe(nil)); end
  end
end

# source://rubocop-rspec_rails//lib/rubocop/rspec_rails/version.rb#4
module RuboCop::RSpecRails; end

# Version information for the RSpec Rails RuboCop plugin.
#
# source://rubocop-rspec_rails//lib/rubocop/rspec_rails/version.rb#6
module RuboCop::RSpecRails::Version; end

# source://rubocop-rspec_rails//lib/rubocop/rspec_rails/version.rb#7
RuboCop::RSpecRails::Version::STRING = T.let(T.unsafe(nil), String)

# frozen_string_literal: true

module Otoroshi
  class Error < StandardError; end

  # Manages errors raised when value type is not as expected
  class WrongTypeError < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    # @param type [Class] class to match
    # @param collection [true, false] define if it is a collection
    def initialize(property, type, collection: false)
      expected_type = type.is_a?(Array) ? type.first || Object : type
      msg =
        if collection
          ":#{property} contains elements that are not instances of #{expected_type}"
        else
          ":#{property} is not an instance of #{expected_type}"
        end
      super(msg)
    end
  end

  # Manages errors raised when value should be an collection
  class NotAnArray < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    def initialize(property)
      msg = ":#{property} is not an array"
      super(msg)
    end
  end

  # Manages errors raised when value is not accepted (not included in the "one_of")
  class NotAcceptedError < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    # @param accepted_values [Array] accepted values
    # @param collection [true, false] define if it is an collection
    def initialize(property, accepted_values, collection: false)
      # reintegrate the colon for symbols which is lost during interpolation
      to_s = ->(v) { v.is_a?(Symbol) ? ":#{v}" : v }
      accepted_values_list = accepted_values.map { |v| to_s.call(v) }.join(', ')
      msg =
        if collection
          ":#{property} contains elements that are not included in [#{accepted_values_list}]"
        else
          ":#{property} is not included in [#{accepted_values_list}]"
        end
      super(msg)
    end
  end

  # Manages errors raised when value does not pass the assertion
  class AssertionError < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    # @param collection [true, false] define if it is an collection
    def initialize(property, collection: false)
      msg =
        if collection
          ":#{property} contains elements that do not respect the assertion"
        else
          ":#{property} does not respect the assertion"
        end
      super(msg)
    end
  end
end

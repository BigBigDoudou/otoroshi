# frozen_string_literal: true

module Otoroshi
  class Error < StandardError; end

  # Manages errors raised when value type is not as expected
  class WrongTypeError < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    # @param type [Class] class to match
    # @param array [true, false] define if it is an array
    def initialize(property, type, array: false)
      expected_type = type.is_a?(Array) ? "[#{type.join(', ')}]" : type
      msg =
        if array
          ":#{property} contains elements that are not instances of #{expected_type}"
        else
          ":#{property} is not an instance of #{expected_type}"
        end
      super(msg)
    end
  end

  # Manages errors raised when value is not accepted (not included in the "one_of")
  class NotAccepted < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    # @param accepted_values [Array] accepted values
    # @param array [true, false] define if it is an array
    def initialize(property, accepted_values, array: false)
      msg =
        if array
          ":#{property} contains elements that are not included in [#{accepted_values.join(', ')}]"
        else
          ":#{property} is not included in [#{accepted_values.join(', ')}]"
        end
      super(msg)
    end
  end

  # Manages errors raised when value does not pass the specific validation
  class SpecificFailure < Error
    # Initialize an error
    #
    # @param property [Symbol] name of the property
    # @param array [true, false] define if it is an array
    def initialize(property, array: false)
      msg =
        if array
          ":#{property} contains elements that do not pass specific validation"
        else
          ":#{property} does not pass specific validation"
        end
      super(msg)
    end
  end
end

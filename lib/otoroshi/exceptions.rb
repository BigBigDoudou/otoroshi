# frozen_string_literal: true

module Otoroshi
  class Error < StandardError; end

  # Manages errors raised when value is not an instance of the expected class
  class TypeError < Error
    # @param property [Symbol] name of the property
    # @param type [Class] class to match
    # @example
    #   ":number is not an instance of Integer"
    def initialize(property, type)
      super ":#{property} is not an instance of #{type}"
    end
  end

  # Manages errors raised when value is not accepted (not in the "one_of")
  class OneOfError < Error
    # @param property [Symbol] name of the property
    # @param values [Array] accepted values
    # @example
    #   ":fruit is not in [:apple, :pear]"
    def initialize(property, values)
      # reintegrate the colon for symbols which is lost during interpolation
      to_s = ->(v) { v.is_a?(Symbol) ? ":#{v}" : v }
      list = values.map { |v| to_s.call(v) }.join(', ')
      super ":#{property} is not in [#{list}]"
    end
  end

  # Manages errors raised when value does not pass the assertion
  class AssertError < Error
    # @param property [Symbol] name of the property
    # @example
    #   ":number does not respect the assertion"
    def initialize(property)
      super ":#{property} does not respect the assertion"
    end
  end

  module Collection
    # Manages errors raised when value should be an collection
    class ArrayError < Error
      # @param property [Symbol] name of the property
      # @example
      #   ":numbers is not an array"
      def initialize(property)
        super ":#{property} is not an array"
      end
    end

    # Manages errors raised when at least one element of the collection is not an instance of the expected class
    class TypeError < Error
      # @param property [Symbol] name of the property
      # @param type [Class] class to match
      # @example
      #   ":numbers contains elements that are not instances of Integer"
      def initialize(property, type)
        super ":#{property} contains elements that are not instances of #{type}"
      end
    end

    # Manages errors raised when at least one element of the collection is not accepted (not in the "one_of")
    class OneOfError < Error
      # @param property [Symbol] name of the property
      # @param values [Array] accepted values
      # @example
      #   ":fruits contains elements that are not in [:apple, :pear]"
      def initialize(property, values)
        # reintegrate the colon for symbols which is lost during interpolation
        to_s = ->(v) { v.is_a?(Symbol) ? ":#{v}" : v }
        list = values.map { |v| to_s.call(v) }.join(', ')
        super ":#{property} contains elements that are not in [#{list}]"
      end
    end

    # Manages errors raised when value does not pass the assertion
    class AssertError < Error
      # @param property [Symbol] name of the property
      # @example
      #   ":numbers contains elements that do not respect the assertion"
      def initialize(property)
        super ":#{property} contains elements that do not respect the assertion"
      end
    end
  end
end

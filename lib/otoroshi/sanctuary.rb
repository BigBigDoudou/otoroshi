# frozen_string_literal: true

require_relative 'initializer'

module Otoroshi
  # This module is designed to be included in a class. This will provide
  # the "property" ({Sanctuary::ClassMethods.property}) method for defining class properties.
  #
  # @example
  #   class Importer
  #     include Otoroshi::Sanctuary
  #
  #     property :whatever
  #     property :number, Integer
  #     property :numbers, [Integer]
  #     property :positive_number, Integer, verify: ->(v) { v >= 0 }
  #     property :number_or_nil, Integer, allow_nil: true
  #     property :number_with_default, Integer, default: 42
  #     property :number_in_collection, Integer, one_of: [1, 2, 3, 5, 8, 13, 21, 34]
  #   end
  module Sanctuary
    class << self
      # Extend ClassMethods for the base class
      def included(base)
        base.extend ClassMethods
      end
    end

    # Class methods extended for the base class
    module ClassMethods
      # Adds a new "property" to the class
      #
      # @param name [Symbol] the property name
      # @param type [Class, Array<Class>] the expected value or values type
      # @param one_of [Array] the accepted values
      # @param assert [Proc] a lambda processing the value and returning true or false
      # @param allow_nil [true, false] allow nil as a value
      # @param default [Object] default value if not set on initialization
      #
      # @return [void]
      #
      # @example
      #   property name, type: String, assert: ->(v) { v.length > 3 }, allow_nil: true
      # @example
      #   property scores, type: [Integer], assert: ->(v) { v >= 0 }, default: []
      def property(name, type = Object, one_of: nil, assert: ->(_) { true }, allow_nil: false, default: nil)
        add_to_properties(name, type, allow_nil, default)
        collection = type == Array || type.is_a?(Array)
        define_validate_type!(name, type, collection, allow_nil)
        define_validate_inclusion!(name, collection, one_of, allow_nil)
        define_validate_assertion!(name, collection, assert, allow_nil)
        define_getter(name)
        define_setter(name)
        class_eval Initializer.draw(properties), __FILE__, __LINE__ + 1
      end

      # Returns the class properties
      #
      # @return [Hash]
      #
      # @note this method will be updated by {add_to_properties}
      def properties
        {}
      end

      private

      # Updates {properties} to add new property to the returned ones
      #
      # @return [void]
      def add_to_properties(name, type, allow_nil, default)
        current_state = properties
        current_state[name] = {
          type: type,
          allow_nil: allow_nil,
          default: default
        }
        define_singleton_method(:properties) { current_state }
      end

      # Defines a private method that raises an error if type is not respected
      #
      # @return [void]
      #
      # @example
      #   define_validate_type!(:score, Integer, false) => def validate_score_type!(value) ...
      # @example Generated method
      #   # given name: :score, type: Integer, allow_nil: false
      #   def validate_score_type!(value)
      #     return if Integer.nil? || false && value.nil?
      #     return if value.is_a? Integer
      #
      #     raise ArgumentError, ":score does not match required type"
      #   end
      def define_validate_type!(name, type, collection, allow_nil)
        lambda = type_validation(type)
        check_collection = ->(v) { v.is_a?(Array) || raise(Otoroshi::NotAnArray, name) }
        define_method :"validate_#{name}_type!" do |value|
          return if allow_nil && value.nil?

          collection && check_collection.call(value)
          return if lambda.call(value)

          raise Otoroshi::WrongTypeError.new(name, type, collection: collection)
        end
        private :"validate_#{name}_type!"
      end

      # Defines a lambda to be called to validate that value matches the type
      #
      # @return [Proc] the lambda to use in order to test that the value matches the type
      #
      # @example
      #   type_validation(Integer) #=> ->(v) { v.is_a? Integer }
      # @example
      #   type_validation([String, Symbol]) #=> ->(v) { [String, Symbol].any? { |t| v.is_a? t } }
      #
      # @note params are used for binding in define_method scope
      def type_validation(type)
        if type == Array
          # no expected type for each element, return nil
          ->(_) {}
        elsif type.is_a?(Array)
          # get the real expected type
          # e.g. if type is [Integer] then element_type should be Integer
          # e.g. if type is [] then element_type should be Object
          element_type = type.first || Object
          # apply type_validation lambda on each element
          ->(v) { v.all? { |e| type_validation(element_type).call(e) } }
        else
          # check the value matches the type
          ->(v) { v.is_a? type }
        end
      end

      # Defines a private method that raises an error if value is not included in the accepted ones
      #
      # @return [void]
      #
      # @example
      #   # given @name = :side
      #   define_validate_inclusion!(:side, ...) => def validate_side_type!(value) ...
      # @example Generated method
      #   # given name: :side, collection: false, one_of: [:left, :right], allow_nil: false
      #   def validate_side_type!(value)
      #     return if false && value.nil?
      #     return if [:left, :right].include? value
      #
      #     raise ArgumentError, ":side is not included in accepted values"
      #   end
      def define_validate_inclusion!(name, collection, one_of, allow_nil)
        validator = collection ? each_inside?(name, one_of) : inside?(name, one_of)
        if one_of
          define_method(:"validate_#{name}_inclusion!") do |value|
            allow_nil && value.nil? || validator.call(value)
          end
        else
          define_method(:"validate_#{name}_inclusion!") { |_| }
        end
        private :"validate_#{name}_inclusion!"
      end

      # Defines a lambda to be called to validate that value is included in accepted ones
      #
      # @return [Proc] the lambda to use in order to test that value is included in accepted ones
      def inside?(name, one_of)
        lambda do |v|
          one_of.include?(v) || raise(Otoroshi::NotAcceptedError.new(name, one_of))
        end
      end

      # Defines a lambda to be called to validate that each value is included in accepted ones
      #
      # @return [Proc] the lambda to use in order to test that each value is included in accepted ones
      def each_inside?(name, one_of)
        lambda do |v|
          v.all? { |e| one_of.include? e } || raise(Otoroshi::NotAcceptedError.new(name, one_of, collection: true))
        end
      end

      # Defines a private method that raises an error if assert lambda returns false
      #
      # @return [void]
      #
      # @example
      #   define_validate_assertion!(:score, ...) #=> def validate_score_assertion!(value) ...
      # @example Generated instance method
      #   # given name: :score, assert: >(v) { v >= 0 }, allow_nil: false
      #   def validate_score_assertion!(value)
      #     return if false && value.nil?
      #     return if value >= 0
      #
      #     raise ArgumentError, ":score does not match validation"
      #   end
      def define_validate_assertion!(name, collection, assert, allow_nil)
        validator = collection ? each_assert?(name, assert) : assert?(name, assert)
        define_method :"validate_#{name}_assertion!" do |value|
          allow_nil && value.nil? || validator.call(value)
        end
        private :"validate_#{name}_assertion!"
      end

      # Defines a lambda to be called to validate that value respects the specific
      #
      # @return [Proc] the lambda to use in order to test that value respects the specific
      def assert?(name, assert)
        lambda do |value|
          instance_exec(value, &assert) || raise(Otoroshi::AssertionError, name)
        end
      end

      # Defines a lambda to be called to validate that value respects the specific
      #
      # @return [Proc] the lambda to use in order to test that each value respects the specific
      def each_assert?(name, assert)
        lambda do |value|
          value.all? { |e| instance_exec(e, &assert) } ||
            raise(Otoroshi::AssertionError.new(name, collection: true))
        end
      end

      # Defines a getter method for the property
      #
      # @return [void]
      #
      # @example
      #   define_getter(:score) #=> def score ...
      # @example Generated instance method
      #   # given name: :score
      #   def score
      #     instance_variable_get(@score)
      #   end
      def define_getter(name)
        define_method(name) { instance_variable_get("@#{name}") }
      end

      # Defines a setter method for the property
      #
      # @return [void]
      #
      # @example
      #   define_setter(:score) #=> def score=(value) ...
      # @example Generated instance method
      #   # given name: :score
      #   def score=(value)
      #     validate_score_type!(value)
      #     validate_score!(value)
      #     instance_variable_set(@score, value)
      #   end
      def define_setter(name)
        define_method :"#{name}=" do |value|
          __send__(:"validate_#{name}_type!", value)
          __send__(:"validate_#{name}_inclusion!", value)
          __send__(:"validate_#{name}_assertion!", value)
          instance_variable_set("@#{name}", value)
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'initializer'

module Otoroshi
  # This module is designed to be in a class. This will provide
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
        expected_type = type.is_a?(Array) ? type.first || Object : type
        collection = expected_type == Array || type.is_a?(Array)
        define_validate_type(name, expected_type, collection, allow_nil)
        define_validate_one_of(name, collection, one_of, allow_nil)
        define_validate_assertion(name, collection, assert, allow_nil)
        define_validate(name)
        define_getter(name)
        define_setter(name)
        class_eval Initializer.draw(properties), __FILE__, __LINE__ + 1
      end

      # Class properties
      #
      # @return [Hash]
      #
      # @example
      #   {
      #     number: { type: Integer, allow_nil: false, default: 0 },
      #     message: { type: Integer, allow_nil: true, default: nil }
      #   }
      def properties
        {}
      end

      private

      # Adds a properties to the {properties}
      def add_to_properties(name, type, allow_nil, default)
        current_state = properties
        current_state[name] = {
          type: type,
          allow_nil: allow_nil,
          default: default
        }
        define_singleton_method(:properties) { current_state }
      end

      # Defines a private method that validates type condition
      #
      #   Given name = :score, type = Integer, allow_nil = false
      #
      #   def validate_score_type(value)
      #     return if Integer.nil? || false && value.nil?
      #     return if value.is_a? Integer
      #
      #     raise Otoroshi::TypeError, :score, Integer
      #   end
      def define_validate_type(name, type, collection, allow_nil)
        validator = validate_type?(name, type, collection)
        define_method :"validate_#{name}_type" do |value|
          allow_nil && value.nil? || validator.call(value)
        end
        private :"validate_#{name}_type"
      end

      # Lambda that validates (value) respects the type condition
      # @return [Proc]
      def validate_type?(name, type, collection)
        if collection
          # validate each element of (v) is an instance of the type
          lambda do |v|
            v.is_a?(Array) || raise(Otoroshi::Collection::ArrayError, name)
            v.all? { |elt| elt.is_a? type } || raise(Otoroshi::Collection::TypeError.new(name, type))
          end
        else
          # validate (v) is an instance of the type
          ->(v) { v.is_a?(type) || raise(Otoroshi::TypeError.new(name, type)) }
        end
      end

      # Defines a private method that validates one_of condition
      #
      #   Given name = :side, collection = false, one_of = [:left, :right], allow_nil = false
      #
      #   def validate_side_type(value)
      #     return if false && value.nil?
      #     return if [:left, :right].include? value
      #
      #     raise Otoroshi::OneOfError, :side, [:left, :right]
      #   end
      def define_validate_one_of(name, collection, one_of, allow_nil)
        validator = validate_one_of?(name, one_of, collection)
        define_method(:"validate_#{name}_one_of") do |value|
          allow_nil && value.nil? || validator.call(value)
        end
        private :"validate_#{name}_one_of"
      end

      # Lambda that validates (value) respects the one_of condition
      # @return [Proc]
      def validate_one_of?(name, one_of, collection)
        return ->(_) {} unless one_of

        if collection
          lambda do |v|
            v.all? { |e| one_of.include? e } || raise(Otoroshi::Collection::OneOfError.new(name, one_of))
          end
        else
          lambda do |v|
            one_of.include?(v) || raise(Otoroshi::OneOfError.new(name, one_of))
          end
        end
      end

      # Defines a private method that validates assert condition
      #
      #   Given name = :score, assert = ->(v) { v >= 0 }, allow_nil = false
      #
      #   def validate_score_assertion(value)
      #     return if false && value.nil?
      #     return if value >= 0
      #
      #     raise Otoroshi::AssertError, :score
      #   end
      def define_validate_assertion(name, collection, assert, allow_nil)
        validator = validate_assert?(name, assert, collection)
        define_method :"validate_#{name}_assertion" do |value|
          allow_nil && value.nil? || validator.call(value)
        end
        private :"validate_#{name}_assertion"
      end

      # Lambda that validates (value) respects the assert condition
      # @return [Proc]
      def validate_assert?(name, assert, collection)
        if collection
          ->(v) { v.all? { |e| instance_exec(e, &assert) } || raise(Otoroshi::Collection::AssertError, name) }
        else
          ->(v) { instance_exec(v, &assert) || raise(Otoroshi::AssertError, name) }
        end
      end

      # Defines a private method that calls all validations
      #
      #   Given name = :score
      #
      #   def validate_score!(value)
      #     validate_score_type(value)
      #     validate_score_one_of(value)
      #     validate_score_assert(value)
      #   end
      def define_validate(name)
        define_method :"validate_#{name}!" do |value|
          __send__(:"validate_#{name}_type", value)
          __send__(:"validate_#{name}_one_of", value)
          __send__(:"validate_#{name}_assertion", value)
        end
        private :"validate_#{name}!"
      end

      # Defines a getter
      #
      #   Given name = :score
      #
      #   def score
      #     instance_variable_get(@score)
      #   end
      def define_getter(name)
        define_method(name) { instance_variable_get("@#{name}").clone.freeze }
      end

      # Defines a setter
      #
      #   Given name = :score
      #
      #   def score=(value)
      #     validate_score_type(value)
      #     validate_score!(value)
      #     instance_variable_set(@score, value)
      #   end
      def define_setter(name)
        define_method :"#{name}=" do |value|
          __send__(:"validate_#{name}!", value)
          instance_variable_set("@#{name}", value)
        end
      end
    end
  end
end

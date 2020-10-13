# frozen_string_literal: true

module Otoroshi
  # Add the ::property helper to the class
  module Sanctuary
    class << self
      # Extend class method to the class
      def included(base)
        base.extend ClassMethods
      end
    end

    # Define class methods
    module ClassMethods
      # Adds a new property to the class
      #
      # @param name [Symbol] the property name
      # @param type [Class] the expected value type
      # @param validate [Proc] a lambda processing the value and returning true or false
      # @param allow_nil [true, false] allow nil as a value
      # @param default [Object, nil] default value if not set on initialization
      # @return [nil]
      # @example
      #   property name, type: String, validate: ->(v) { v.length > 3 }, allow_nil: true
      # @example
      #   property score, type: Integer, validate: ->(v) { v >= 0 }, default: 0
      def property(name, type = Object, validate: ->(_) { true }, allow_nil: false, default: nil)
        add_to_properties(name, allow_nil, default)
        define_validate_type!(name, type, allow_nil)
        define_validate_lambda!(name, validate, allow_nil)
        define_getter(name)
        define_setter(name)
        redefine_initialize
      end

      # Return the (inherited) class properties
      # (this method will be updated by ::add_to_properties)
      #
      def properties
        {}
      end

      private

      # Update the ::properties method to add new property to the current list
      #
      def add_to_properties(name, allow_nil, default)
        current_state = properties
        current_state[name] = { allow_nil: allow_nil, default: default }
        define_singleton_method(:properties) { current_state }
      end

      # Define a private method that raises an error if type is not respected
      #
      # / Examples
      #
      # ::define_validate_type!("score", Integer, false) --> will define:
      #
      # def validate_score_type!(value)
      #   return if allow_nil && value.nil?
      #   return if value.is_a?(Integer)
      #
      #   raise ArgumentError, ":score does not match required type"
      # end
      #
      def define_validate_type!(name, type, allow_nil)
        lambda = type_validation(type)
        define_method :"validate_#{name}_type!" do |value|
          return if type.nil? || allow_nil && value.nil?
          return if lambda.call(value)

          raise ArgumentError, ":#{name} does not match required type"
        end
        private :"validate_#{name}_type!"
      end

      # Define a lambda to be call to validate that value match the type
      # ----------------------------------------------------------------
      #
      # / Examples
      #
      # ::type_validation(Integer) --> will return:
      # ->(v) { v.is_a? Integer }
      #
      # :type_validation([String, Symbol]) --> will return:
      # ->(v) { [String, Symbol].any? { |t| v.is_a? t } }
      #
      def type_validation(type)
        if type.is_a? Array
          ->(v) { type.any? { |t| v.is_a? t } }
        else
          ->(v) { v.is_a? type }
        end
      end

      # Define a private method that raises an error if validate block returns false
      # ----------------------------------------------------------------------------
      #
      # / Examples
      #
      # ::define_validate_lambda!("score", ->(v) { v >= 0 }, false) --> will define:
      #
      # def validate_score_lambda!(value)
      #   return if false && value.nil?
      #   return if value >= 0
      #
      #   raise ArgumentError, ":score does not match validation"
      # end
      #
      def define_validate_lambda!(name, validate, allow_nil)
        define_method :"validate_#{name}_lambda!" do |value|
          return if allow_nil && value.nil?
          return if instance_exec(value, &validate)

          raise ArgumentError, ":#{name} does not match validation"
        end
        private :"validate_#{name}_lambda!"
      end

      # Define a getter method for the property
      # ---------------------------------------
      #
      # / Examples
      #
      # ::define_getter("score") --> will define:
      #
      # def score
      #   @score
      # end
      #
      def define_getter(name)
        define_method(name) { instance_variable_get("@#{name}") }
      end

      # Define a setter method for the property
      # ---------------------------------------
      #
      # / Examples
      #
      # ::define_setter("score") --> will define:
      #
      # def score=(value)
      #   validate_score_type!(value)
      #   validate_score!(value)
      #   @score = value
      # end
      #
      def define_setter(name)
        define_method :"#{name}=" do |value|
          __send__(:"validate_#{name}_type!", value)
          __send__(:"validate_#{name}_lambda!", value)
          instance_variable_set("@#{name}", value)
        end
      end

      # Redefine the initialize method
      # ------------------------------
      #
      # / Examples
      #
      # Given the properties:
      #   foo: { allow_nil: false, default: nil }
      #   bar: { allow_nil: true, default: 0 }
      #
      # ::define_initialize --> will define:
      #
      # def initialize(foo:, bar: 0)
      #   self.foo = foo
      #   self.bar = bar
      # end
      #
      def redefine_initialize
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def initialize(#{initialize_parameters})
            #{initialize_body}
          end
        RUBY
      end

      # Define initialize method parameters
      # -----------------------------------
      #
      # / Examples
      #
      # Given the properties:
      #   foo: { allow_nil: false, default: nil }
      #   bar: { allow_nil: true, default: 0 }
      #
      # ::initialize_parameters --> will return:
      # "foo:, bar: 0"
      #
      def initialize_parameters
        properties.map { |key, options| "#{key}:#{default_parameter_for(options)}" }.join(', ')
      end

      # Define the default value of a parameter depending on options
      # ------------------------------------------------------------
      #
      # / Examples
      #
      # default_parameter_for(allow_nil: true, default: 0) --> will return
      #   ' 0'
      #
      # default_parameter_for(allow_nil: true, default: nil) --> will return
      #   ' nil'
      #
      # default_parameter_for(allow_nil: false, default: nil) --> will return
      #   ''
      #
      def default_parameter_for(options)
        return " #{options[:default]}" if options[:default]

        options[:allow_nil] ? ' nil' : ''
      end

      # Define initialize method body
      # -----------------------------
      #
      # / Examples
      #
      # Given the properties:
      #   :foo, :bar
      #
      # ::initialize_body --> will return:
      #   "self.foo = foo
      #    self.bar = bar"
      #
      def initialize_body
        properties.keys.map { |key| "self.#{key} = #{key}" }.join("\n")
      end
    end
  end
end

# frozen_string_literal: true

module Otoroshi
  # This module is designed to be included in a class. This will provide
  # the "property" ({Sanctuary::ClassMethods.property}) method for defining class properties.
  # @example
  #   class Importer
  #     include Otoroshi::Sanctuary
  #
  #     property :file_path, String, validate: ->(v) { v.match? /.+\.csv/ }
  #     property :headers, [TrueClass, FalseClass], default: false
  #     property :col_sep, String, validate: ->(v) { v.in? [',', ';', '\s', '\t', '|'] }, default: ','
  #     property :converters, Symbol, validate: ->(v) { v.in? %i[integer float date] }, allow_nil: true
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
      # @param name [Symbol] the property name
      # @param type [Class] the expected value type
      # @param validate [Proc] a lambda processing the value and returning true or false
      # @param allow_nil [true, false] allow nil as a value
      # @param default [Object] default value if not set on initialization
      # @return [void]
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

      # Returns the class properties
      # @return [Hash]
      # @note this method will be updated by {add_to_properties}
      def properties
        {}
      end

      private

      # Updates {properties} to add new property to the returned ones
      # @return [void]
      def add_to_properties(name, allow_nil, default)
        current_state = properties
        current_state[name] = { allow_nil: allow_nil, default: default }
        define_singleton_method(:properties) { current_state }
      end

      # Defines a private method that raises an error if type is not respected
      # @param name [Symbol] the property name
      # @param type [Class] the type to test against
      # @param allow_nil [true, false] allow nil as a value
      # @return [void]
      # @example
      #   define_validate_type!(score, Integer, false) => def validate_score_type!(value) ...
      # @example Generated method
      #   def validate_score_type!(value)
      #     return if Integer.nil? || false && value.nil?
      #     return if value.is_a? Integer
      #
      #     raise ArgumentError, ":score does not match required type"
      #   end
      def define_validate_type!(name, type, allow_nil)
        lambda = type_validation(type)
        define_method :"validate_#{name}_type!" do |value|
          return if type.nil? || allow_nil && value.nil?
          return if lambda.call(value)

          raise ArgumentError, ":#{name} does not match required type"
        end
        private :"validate_#{name}_type!"
      end

      # Defines a lambda to be call to validate that value matches the type
      # @param type [Class] the type to test against
      # @return [Proc] the lambda to use in order to test the value matches the type
      # @example
      #   type_validation(Integer) #=> ->(v) { v.is_a? Integer }
      # @example
      #   type_validation([String, Symbol]) #=> ->(v) { [String, Symbol].any? { |t| v.is_a? t } }
      def type_validation(type)
        if type.is_a? Array
          ->(v) { type.any? { |t| v.is_a? t } }
        else
          ->(v) { v.is_a? type }
        end
      end

      # Defines a private method that raises an error if validate block returns false
      # @param name [Symbol] the property name
      # @param validate [Proc] a lambda processing the value and returning true or false
      # @param allow_nil [true, false] allow nil as a value
      # @return [void]
      # @example
      #   define_validate_lambda!("score", ->(v) { v >= 0 }, false) #=> def validate_score_lambda!(value) ...
      # @example Generated instance method
      #   def validate_score_lambda!(value)
      #     return if false && value.nil?
      #     return if value >= 0
      #
      #     raise ArgumentError, ":score does not match validation"
      #   end
      def define_validate_lambda!(name, validate, allow_nil)
        define_method :"validate_#{name}_lambda!" do |value|
          return if allow_nil && value.nil?
          return if instance_exec(value, &validate)

          raise ArgumentError, ":#{name} does not match validation"
        end
        private :"validate_#{name}_lambda!"
      end

      # Defines a getter method for the property
      # @param name [Symbol] the property name
      # @return [void]
      # @example
      #   define_getter(:score) #=> def score ...
      # @example Generated instance method
      #     def score
      #       instance_variable_get(@score)
      #     end
      def define_getter(name)
        define_method(name) { instance_variable_get("@#{name}") }
      end

      # Defines a setter method for the property
      # @param name [Symbol] the property name
      # @return [void]
      # @example
      #   define_getter(:score) #=> def score=(value) ...
      # @example Generated instance method
      #   def score=(value)
      #     validate_score_type!(value)
      #     validate_score!(value)
      #     instance_variable_set(@score, value)
      #   end
      def define_setter(name)
        define_method :"#{name}=" do |value|
          __send__(:"validate_#{name}_type!", value)
          __send__(:"validate_#{name}_lambda!", value)
          instance_variable_set("@#{name}", value)
        end
      end

      # Redefines initialize method
      # @return [void]
      # @note method is defined with `class_eval`
      # @example Generated method
      #   def initialize(foo:, bar: 0)
      #     self.foo = foo
      #     self.bar = bar
      #   end
      def redefine_initialize
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def initialize(#{initialize_parameters})
            #{initialize_body}
          end
        RUBY
      end

      # Defines initialize method parameters
      # @return [String]
      # @example Given properties { foo: { allow_nil: false, default: nil }, { allow_nil: true, default: 0 } }
      #   redefine_initialize #=> "foo:, bar: 0"
      def initialize_parameters
        parameters =
          properties.map do |key, options|
            allow_nil, default = options.values
            "#{key}:#{default_parameter_for(allow_nil, default)}"
          end
        parameters.join(', ')
      end

      # Defines the default value of a parameter depending on options
      # @param options [Hash]
      # @return [String]
      # @example when nil is allowed and default is set
      #   default_parameter_for(true, 0) #=> " 0"
      # @example when nil is allowed and default is not set
      #   default_parameter_for(true, nil) #=> " nil"
      # @example when nil is not allowed
      #   default_parameter_for(false, nil) #=> ""
      def default_parameter_for(allow_nil, default)
        return " #{default}" if default

        allow_nil ? ' nil' : ''
      end

      # Defines initialize method body
      # @return [String]
      # @example Given properties { foo: { allow_nil: false, default: nil }, { allow_nil: true, default: 0 } }
      #   initialize_body #=> "self.foo = foo\nself.bar = bar"
      def initialize_body
        properties.keys.map { |key| "self.#{key} = #{key}" }.join("\n")
      end
    end
  end
end

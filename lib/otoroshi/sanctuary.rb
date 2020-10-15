# frozen_string_literal: true

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
  #     property :number_from_collection, Integer, one_of: [1, 2, 3, 5, 8, 13, 21, 34]
  #   end
  module Sanctuary
    class << self
      # Extend ClassMethods for the base class
      def included(base)
        base.extend ClassMethods
      end
    end

    # Class methods extended for the base class
    module ClassMethods # rubocop:disable Metrics/ModuleLength
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
      def property( # rubocop:disable Metrics/ParameterLists
        name,
        type = Object,
        one_of: nil,
        assert: ->(_) { true },
        allow_nil: false,
        default: nil
      )
        add_to_properties(name, type, one_of, assert, allow_nil, default)
        define_validate_type!(name, type, allow_nil)
        define_validate_inclusion!(name, type, one_of, allow_nil)
        define_validate_assertion!(name, type, assert, allow_nil)
        define_getter(name)
        define_setter(name)
        redefine_initialize
      end

      # Checks the type is an array
      #
      # @param type [Class, Array<Class>] the tested type
      #
      # @return [true, false]
      def collection?(type)
        type == Array || type.is_a?(Array)
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
      def add_to_properties(name, type, one_of, assert, allow_nil, default) # rubocop:disable Metrics/ParameterLists
        current_state = properties
        current_state[name] = {
          type: type,
          one_of: one_of,
          assert: assert,
          allow_nil: allow_nil,
          default: default
        }
        define_singleton_method(:properties) { current_state }
      end

      # Defines a private method that raises an error if type is not respected
      #
      # @param name [Symbol] the property name
      # @param type [Class] the type to test against
      # @param array [true, false] define if the value is an array
      # @param allow_nil [true, false] allow nil as a value
      #
      # @return [void]
      #
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
        is_array = collection?(type)
        check_array = ->(v) { v.is_a?(Array) || raise(Otoroshi::NotAnArray, name) }
        define_method :"validate_#{name}_type!" do |value|
          return if allow_nil && value.nil?

          is_array && check_array.call(value)
          return if lambda.call(value)

          raise Otoroshi::WrongTypeError.new(name, type, array: is_array)
        end
        private :"validate_#{name}_type!"
      end

      # Defines a lambda to be called to validate that value matches the type
      #
      # @param type [Class] the type to test against
      # @param array [true, false] define if the value is an array
      #
      # @return [Proc] the lambda to use in order to test that the value matches the type
      #
      # @example
      #   type_validation(Integer) #=> ->(v) { v.is_a? Integer }
      # @example
      #   type_validation([String, Symbol]) #=> ->(v) { [String, Symbol].any? { |t| v.is_a? t } }
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
      # @param name [Symbol] the property name
      # @param array [true, false] define if the value is an array
      # @param values [Array, nil] the values to test against
      # @param allow_nil [true, false] allow nil as a value
      #
      # @return [void]
      #
      # @example
      #   define_validate_inclusion!(side, [:left, :right], false) => def validate_side_type!(value) ...
      # @example Generated method
      #   def validate_side_type!(value)
      #     return if false && value.nil?
      #     return if [:left, :right].include? value
      #
      #     raise ArgumentError, ":side is not included in accepted values"
      #   end
      def define_validate_inclusion!(name, type, values, allow_nil)
        validator = collection?(type) ? each_inside?(name, values) : inside?(name, values)
        if values
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
      # @param name [Symbol] the property name
      # @param values [Array, nil] the values to test against
      #
      # @return [Proc] the lambda to use in order to test that value is included in accepted ones
      def inside?(name, values)
        lambda do |v|
          values.include?(v) || raise(Otoroshi::NotAcceptedError.new(name, values))
        end
      end

      # Defines a lambda to be called to validate that each value is included in accepted ones
      #
      # @param name [Symbol] the property name
      # @param values [Array, nil] the values to test against
      #
      # @return [Proc] the lambda to use in order to test that each value is included in accepted ones
      def each_inside?(name, values)
        lambda do |v|
          v.all? { |e| values.include? e } || raise(Otoroshi::NotAcceptedError.new(name, values, array: true))
        end
      end

      # Defines a private method that raises an error if assert lambda returns false
      #
      # @param name [Symbol] the property name
      # @param assert [Proc] a lambda processing the value and returning true or false
      # @param allow_nil [true, false] allow nil as a value
      #
      # @return [void]
      #
      # @example
      #   define_validate_assertion!("score", ->(v) { v >= 0 }, false) #=> def validate_score_assertion!(value) ...
      # @example Generated instance method
      #   def validate_score_assertion!(value)
      #     return if false && value.nil?
      #     return if value >= 0
      #
      #     raise ArgumentError, ":score does not match validation"
      #   end
      def define_validate_assertion!(name, type, assert, allow_nil)
        validator = collection?(type) ? each_assert?(name, assert) : assert?(name, assert)
        define_method :"validate_#{name}_assertion!" do |value|
          allow_nil && value.nil? || validator.call(value)
        end
        private :"validate_#{name}_assertion!"
      end

      # Defines a lambda to be called to validate that value respects the specific
      #
      # @param name [Symbol] the property name
      # @param assert [Proc] a lambda processing the value and returning true or false
      #
      # @return [Proc] the lambda to use in order to test that value respects the specific
      def assert?(name, assert)
        lambda do |value|
          return if instance_exec(value, &assert)

          raise Otoroshi::AssertionError, name
        end
      end

      # Defines a lambda to be called to validate that value respects the specific
      #
      # @param name [Symbol] the property name
      # @param validate [Proc] a lambda processing the value and returning true or false
      #
      # @return [Proc] the lambda to use in order to test that each value respects the specific
      def each_assert?(name, validate)
        lambda do |value|
          return if value.all? { |e| instance_exec(e, &validate) }

          raise Otoroshi::AssertionError.new(name, array: true)
        end
      end

      # Defines a getter method for the property
      #
      # @param name [Symbol] the property name
      #
      # @return [void]
      #
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
      #
      # @param name [Symbol] the property name
      #
      # @return [void]
      #
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
          __send__(:"validate_#{name}_inclusion!", value)
          __send__(:"validate_#{name}_assertion!", value)
          instance_variable_set("@#{name}", value)
        end
      end

      # Redefines initialize method
      #
      # @return [void]
      #
      # @note method is defined with `class_eval`
      #
      # @example Generated method
      #   def initialize(foo:, bar: 0)
      #     self.foo = foo
      #     self.bar = bar
      #   end
      def redefine_initialize
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def initialize(#{initialize_parameters})
            #{initialize_assignments}
            #{initialize_push_singletons}
          end
        RUBY
      end

      # Generates initialize method parameters
      #
      # @return [String]
      #
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

      # Fixes the default value of a parameter depending on options
      #
      # @param options [Hash]
      #
      # @return [String]
      #
      # @example when nil is allowed and default is set
      #   default_parameter_for(true, 0) #=> " 0"
      # @example when nil is allowed and default is not set
      #   default_parameter_for(true, nil) #=> " nil"
      # @example when nil is not allowed
      #   default_parameter_for(false, nil) #=> ""
      def default_parameter_for(allow_nil, default)
        if default
          symbol_prefix = default.is_a?(Symbol) ? ':' : ''
          " #{symbol_prefix}#{default}"
        else
          allow_nil ? ' nil' : ''
        end
      end

      # Generates initialize method assignments
      #
      # @return [String]
      #
      # @example Given properties { foo: { allow_nil: false, default: nil }, { allow_nil: true, default: 0 } }
      #   initialize_body #=> "self.foo = foo\nself.bar = bar"
      def initialize_assignments
        properties.keys.map { |name| "self.#{name} = #{name}" }.join("\n")
      end

      # Generates push singleton for each array property
      #
      # @return [String]
      def initialize_push_singletons
        collections = properties.select { |_, options| collection?(options[:type]) }
        singletons =
          collections.keys.map { |name| initialize_push_singleton(name) }
        singletons.join("\n")
      end

      # Generates singleton on array instance variable to overide <<
      # so value is validated before being added to the array
      #
      # @return [String]
      def initialize_push_singleton(name)
        <<-RUBY
        bind = self
        @#{name}.singleton_class.send(:define_method, :<<) do |v|
          bind.send(:"validate_#{name}_type!", [v])
          bind.send(:"validate_#{name}_inclusion!", [v])
          bind.send(:"validate_#{name}_assertion!", [v])

          push(v)
        end
        RUBY
      end
    end
  end
end

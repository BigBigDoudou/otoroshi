# frozen_string_literal: true

module Otoroshi
  # help setting and validating instance arguments
  class Sanctuary
    class << self
      # Add a new property to the class (called by inherited class)
      # Example: property name, type: String, validate: ->(v) { v.length > 3 }, allow_nil: true
      def property(name, type = Object, validate: ->(_) { true }, allow_nil: false, default: nil)
        define_default(name, default)
        define_validate_type!(name, type, allow_nil)
        define_validate!(name, validate, allow_nil)
        define_getter(name)
        define_setter(name)
        add_to_properties(name)
      end

      # Return the (inherited) class properties
      # (this method will be updated by ::add_to_properties(name))
      def properties
        []
      end

      private

      # Update the ::properties method to add new property to the current list
      def add_to_properties(name)
        current = properties
        define_singleton_method :properties do
          current << name
        end
      end

      # Define a private method that returns the default value
      #
      # ::define_default("score", 0)
      # --------------------------
      # def default_score
      #   0
      # end
      #
      def define_default(name, default)
        define_method(:"default_#{name}") { default }
        private :"default_#{name}"
      end

      # Define a private method that raises an error if type is not respected
      #
      # ::define_validate_type!("score", Integer, false)
      # ----------------------------------------------
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
      #
      # ::type_validation(Integer)
      # ----------------------------------------------
      # ->(v) { v.is_a? Integer }
      #
      def type_validation(type)
        if type.is_a? Array
          ->(v) { type.any? { |t| v.is_a? t } }
        else
          ->(v) { v.is_a? type }
        end
      end

      # Define a private method that raises an error if validate block returns false
      #
      # ::define_validate!("score", ->(v) { v >= 0 }, false)
      # --------------------------------------------------
      # def validate_score!(value)
      #   return if false && value.nil?
      #   return if value >= 0
      #
      #   raise ArgumentError, ":score does not match validation"
      # end
      #
      def define_validate!(name, validate, allow_nil)
        define_method :"validate_#{name}!" do |value|
          return if allow_nil && value.nil?
          return if instance_exec(value, &validate)

          raise ArgumentError, ":#{name} does not match validation"
        end
        private :"validate_#{name}!"
      end

      # Define a getter method for the property
      #
      # ::define_getter("score")
      # ----------------------
      # def score
      #   @score
      # end
      #
      def define_getter(name)
        define_method(name) { instance_variable_get("@#{name}") }
      end

      # Define a setter method for the property
      #
      # ::define_setter("score")
      # ----------------------
      # def score=(value)
      #   validate_score_type!(value)
      #   validate_score!(value)
      #   @score = value
      # end
      #
      def define_setter(name)
        define_method :"#{name}=" do |value|
          __send__(:"validate_#{name}_type!", value)
          __send__(:"validate_#{name}!", value)
          instance_variable_set("@#{name}", value)
        end
      end
    end

    # Initialize an instance and validate provided args
    def initialize(args = {}) # rubocop:disable Style/OptionHash
      validate_keys!(args.keys)
      assign_values(args)
    end

    private

    # validate that provided keys match class properties
    def validate_keys!(keys)
      errors = keys.reject { |key| self.class.properties.include? key }
      return if errors.empty?

      message =
        if errors.one?
          ":#{errors[0]} is not a valid property"
        else
          ":#{errors.join(', :')} are not valid properties"
        end
      raise ArgumentError, message
    end

    # assign value to each property
    def assign_values(args)
      self.class.properties.each do |property|
        value = args.key?(property) ? args[property] : __send__(:"default_#{property}")
        public_send(:"#{property}=", value)
      end
    end
  end
end

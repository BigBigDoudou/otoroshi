# frozen_string_literal: true

module Otoroshi
  # Drawing of #initialize method
  #
  class Initializer
    class << self
      # Draw a stringified initialize method
      #
      # @param properties [Hash] a description of the class properties
      #
      # @return [String]
      #
      # @example
      #   <<-RUBY
      #   def initialize(number: 0, message:, fruits: [])
      #     self.number = number
      #     self.message = message
      #     self.fruits = fruits
      #     bind = self
      #     @fruits.singleton_class.send(:define_method, :<<) do |v|
      #       bind.send(:"validate_fruits!", [v])
      #       push(v)
      #     end
      #   end
      #   RUBY
      def draw(properties)
        new(properties).draw
      end
    end

    # Initialize an instance
    #
    # @param properties [Hash] a description of the class properties
    def initialize(properties = {})
      @properties = properties
    end

    # Draws a stringified initialize method
    #
    # @return [String]
    #
    # @example
    #   <<-RUBY
    #   def initialize(foo:, bar: 0)
    #     self.foo = foo
    #     self.bar = bar
    #   end
    #   RUBY
    def draw
      <<-RUBY
        def initialize(#{initialize_parameters})
          #{initialize_assignments}
          #{initialize_push_singletons}
        end
      RUBY
    end

    private

    attr_reader :properties

    # Generates initialize method parameters
    #
    # @return [String]
    #
    # @example
    #   "foo:, bar: 0"
    def initialize_parameters
      parameters =
        properties.map do |key, options|
          "#{key}:#{default_parameter_for(options)}"
        end
      parameters.join(', ')
    end

    # Generates the default value of a parameter depending on options
    #
    # @return [String]
    #
    # @example when nil is allowed and default is set
    #   " \"default\""
    # @example when nil is allowed and default is not set
    #   " nil"
    # @example when nil is not allowed
    #   ""
    def default_parameter_for(options)
      default, allow_nil = options.values_at(:default, :allow_nil)
      if default
        prefix =
          case default
          when Symbol then ':'
          when String then '"'
          end
        suffix =
          case default
          when String then '"'
          end

        " #{prefix}#{default}#{suffix}"
      else
        allow_nil ? ' nil' : ''
      end
    end

    # Generates initialize method assignments
    #
    # @return [String]
    #
    # @example Given properties { foo: { allow_nil: false, default: nil }, { allow_nil: true, default: 0 } }
    #   <<-RUBY
    #   self.foo = foo
    #   self.bar = bar
    #   RUBY
    def initialize_assignments
      assignments =
        properties.keys.map do |name|
          "self.#{name} = #{name}"
        end
      assignments.join("\n")
    end

    # Generates push singleton for each array property
    #
    # @return [String]
    #
    # @example
    #   <<-RUBY
    #   bind = self
    #   @fruits.singleton_class.send(:define_method, :<<) do |v|
    #     bind.send(:"validate_fruits!", [v])
    #     push(v)
    #   end
    #   @numbers.singleton_class.send(:define_method, :<<) do |v|
    #     bind.send(:"validate_numbers!", [v])
    #     push(v)
    #   end
    #   RUBY
    def initialize_push_singletons
      collections =
        properties.select do |_, options|
          options[:type].is_a?(Array) || options[:type] == Array
        end
      return if collections.empty?

      singletons =
        collections.keys.map do |name|
          initialize_push_singleton(name)
        end
      # assign self to a variable so the instance is accessible from the singleton scope
      singletons.unshift('bind = self').join("\n")
    end

    # Generates singleton on collection instance variable to overide <<
    # so value is validated before being added to the collection
    #
    # @return [String]
    #
    # @example
    #   <<-RUBY
    #   @fruits.singleton_class.send(:define_method, :<<) do |v|
    #     bind.send(:"validate_fruits!", [v])
    #     push(v)
    #   end
    #   RUBY
    def initialize_push_singleton(name)
      <<-RUBY
      @#{name}.singleton_class.send(:define_method, :<<) do |v|
        bind.send(:"validate_#{name}!", [v])

        push(v)
      end
      RUBY
    end
  end
end

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
      <<~RUBY
        def initialize(#{initialize_parameters})
          #{initialize_body}
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
      return " #{default.call}" if default.is_a? Proc
      return ' nil' if default.nil? && allow_nil
      return '' if default.nil? && !allow_nil

      " #{prefix(default)}#{default}#{suffix(default)}"
    end

    # Generates the characters to put before the value
    # @note it avoids symbol without colon or string without quotes
    #   which would be interpreted as methods
    def prefix(default)
      case default
      when Symbol then ':'
      when String then '"'
      when Time, Date, DateTime then '"'
      end
    end

    # Generates the characters to put after the value
    # @note it avoids string without quotes which would be interpreted as method
    def suffix(default)
      case default
      when String then '"'
      when Time, Date, DateTime then '"'
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
    def initialize_body
      assignments =
        properties.keys.map do |name|
          "self.#{name} = #{name}"
        end
      assignments.join("\n  ")
    end
  end
end

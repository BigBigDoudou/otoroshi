# Otoroshi

![otoroshi](https://upload.wikimedia.org/wikipedia/commons/4/41/Suushi_Otoroshi.jpg "Sawaki Suushi")

> -- <cite>Illustration from Sawaki Suushi, 1737</cite>

Otoroshis are legendary creatures in Japanese folklore and mythology. They act as guardian of holy temples.

The `otoroshi` gem helps you defining and validating class properties.

See [an example of refactor](#refactor-example) with Otoroshi.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'otoroshi'
```

And then execute:
```
$ bundle
```

## Usage

Include `Otoroshi::Sanctuary` in a class to easily define arguments validation.

```ruby
class MyClass
  include Otoroshi::Sanctuary
end
```

### Define class's properties

Use the `::property(name, type, options)` method to add a property.

* `name`: name of the property (symbol or string)
* `type`: the class the future value should belongs to (class or array of classes, `Object` by default)
* options:
  * `array`: define if the expected value should be an array (boolean, `false` by default)
  * `one_of`: a list of accepted value (array, `nil` by default)
  * `validate`: a custom validation to apply to the future value (lambda, `->(_) { true }` by default)
  * `allow_nil`: define if the future value can be set to nil (boolean, `false` by default)
  * `default`: the default value for this property (should match the required type, `nil` by default)

Getters and a setters are automatically set:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, Integer
  property :bar, String
end

instance = Example.new(foo: 42, bar: 'hello')

instance.foo # 42
instance.bar # hello

instance.foo = 7
instance.bar = 'world'

instance.foo # 7
instance.bar # world
```

Type validations run on initialization and assignment:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, Integer
end

Example.new # Otoroshi::WrontTypeError, :foo is not an instance of Integer
Example.new(foo: 1.5) # Otoroshi::WrontTypeError, :foo is not an instance of Integer

instance.foo = nil # Otoroshi::WrontTypeError, :foo is not an instance of Integer
instance.foo = 1.5 # Otoroshi::WrontTypeError, :foo is not an instance of Integer
```

You can provide multiple authorized types:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, [Symbol, String]
  property :bar, [TrueClass, FalseClass]
end

Example.new(foo: :hello, bar: true)
Example.new(foo: 'hello', bar: false)
```

You can avoid the second argument so any `Object` can be passed:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo
end

Example.new(foo: 'hello')
Example.new(foo: 42)
Example.new(foo: User.find(1))
```

Use the `one_of` option to list accpeted values:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, one_of: [:apple, :pear]
end

Example.new(foo: :pear)
Example.new(foo: :banana) # Otoroshi::NotAcceptedError, :foo is not included in [apple, pear]

instance.foo = :pear
instance.foo = :banana # Otoroshi::NotAcceptedError, :foo is not included in [apple, pear]
```

You can add custom validations with the `validate:` option.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, Integer, validate: ->(v) { v > 0 }
end

Example.new(foo: -1) # Otoroshi::SpecificValidationError, :foo does not pass specific validation

instance.foo = -1 # Otoroshi::SpecificValidationError, :foo does not pass specific validation
```

Set `allow_nil:` option to `true` if `nil` is authorized:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, Integer, validate: ->(v) { v > 0 }, allow_nil: true
end

instance = Example.new
instance.foo # nil

instance.foo = 42
instance.foo = nil
instance.foo # nil
instance.foo = -1 # Otoroshi::SpecificValidationError, :foo does not pass specific validation
```

Set `default:` option to the default value. You can always set the value to `nil` if `allow_nil` is `true`.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, Integer, validate: ->(v) { v > 0 }, default: 1, allow_nil: true
end

instance = Example.new
instance.foo # 1

instance = Example.new(foo: nil)
instance.foo # nil

instance.foo = nil
instance.foo # nil
```

Set `array:` to `true` to apply the validations on each element.

`allow_nil` and `default` still refer to the array, not the elements.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :foo, Integer, validate: ->(v) { v > 0 }, default: [], allow_nil: true
end

instance = Example.new
instance.foo # []

instance = Example.new(foo: [])
instance = Example.new(foo: [1, 2])

instance = Example.new(foo: [1, 1.5]) # Otoroshi::WrontTypeError, :foo contains elements that are not instances of Integer
```

## Refactor Example

### Before refactor (28 lines dedicated to properties)

```ruby
class Importer
  attr_reader :file_path, :headers, :col_sep, :converters, :column_names

  def initialize(file_path:, headers: false, col_sep: ',', converters: nil, column_names: [])
    self.file_path = file_path
    self.headers = headers
    self.col_sep = col_sep
    self.converters = converters
    self.column_names = column_names
  end

  private

  # private business methods...

  def file_path=(value)
    raise ArgumentError unless value.is_?(String) && value.match?(/.+\.csv/)

    @file_path = value
  end

  def headers=(value)
    raise ArgumentError unless [true, false].include?(value)

    @headers = value
  end

  def col_sep=(value)
    raise ArgumentError unless value.is_?(String) && value.in?([',', ';', '\s', '\t', '|'])

    @col_sep = value
  end

  def converters=(value)
    raise ArgumentError unless value.is_?(Symbol) && value.in?(%i[integer float date])

    @converters = value
  end

  def column_names=(value)
    raise ArgumentError unless value.is_a?(Array) && value.all? { |elt| elt.is_a?(String) && elt.length > 3 }

    @column_names = value
  end
end
```

### After refactor with Otoroshi (6 lines dedicated to properties)

```ruby
class Importer
  include Otoroshi::Sanctuary

  property :file_path, String, validate: ->(v) { v.match? /.+\.csv/ }
  property :headers, [TrueClass, FalseClass], default: false
  property :col_sep, one_of: [',', ';', '\s', '\t', '|'], default: ','
  property :converters, one_of: [:integer, :float, :date], allow_nil: true
  property :column_names, String, array: true, validate: ->(v) { v.length > 3 }, default: []

  private

  # private business methods...
end
```
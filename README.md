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
require 'otoroshi'

class MyClass
  include Otoroshi::Sanctuary
end
```

### Define class's properties

The `::property(name, type, options)` method add a property.

* `name`: name of the property (symbol or string)
* `type`: the class the future value should belongs to (class or array of classes, `Object` by default)
* options:
  * `array`: define if the expected value should be an array (boolean, `false` by default)
  * `one_of`: a list of accepted value (array, `nil` by default)
  * `assert`: a custom assertion to apply to the value (lambda, `->(_) { true }` by default)
  * `allow_nil`: define if the future value can be set to nil (boolean, `false` by default)
  * `default`: the default value for this property (should match the required type, `nil` by default)

Getters and a setters are automatically set.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :quantity, Integer
  property :message, String
  property :fruits, [Symbol]
end

instance = Example.new(quantity: 42, message: 'hello', fruits: [:apple, :pear])

instance.quantity # 42
instance.message # hello
instance.fruits # [:apple, :pear]

instance.quantity = 7
instance.message = 'world'
instance.fruits # [:apple, :pear, :banana]

instance.quantity # 7
instance.message # world
instance.fruits # [:apple, :pear, :banana]
```

Variables are protected so they cannot be mutated.

```ruby
# # Those examples raise a FrozenError
instance.message.upcase!
instance.fruits << :coconut
```

Validations run on initialization and assignment, starting by a type check.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :quantity, Integer
end

# Those examples raise an Otoroshi::WrontTypeError
# with message: ":quantity is not an instance of Integer"
Example.new
Example.new(quantity: 1.5)
instance.quantity = nil
instance.quantity = 1.5
```

If type is not provided it will be set to `Object` so anything can be assigned.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :thing # == property :thing, Object
end

# Those examples won't raise any error
Example.new
Example.new(thing: 'hello')
Example.new(thing: 42)
Example.new(thing: [1, 2, 3])
```

If type is `[]` or `Array`, each element are treated as `Object`.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :things, [] # == property :things, [Object]
end

# These examples won't raise any error
Example.new
Example.new(things: ['a', 'b', 'c'])
Example.new(things: [1, 2, 3])
Example.new(things: [[], []])
```

The `one_of` option limits the accepted values.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :eatable, one_of: [true, false]
end

# These examples raise an Otoroshi::OneOfError
# with message: "eatable is not in [true, false]"
Example.new(eatable: 'maybe')
instance.eatable = 'maybe'
```

If property is an array, the `one_of` is applied to each element.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :fruits, [], one_of: [:apple, :pear]
end

# These examples raise an Otoroshi::OneOfError
# with message: ":fruits contains elements that are not in [:apple, :pear]"
Example.new(fruits: [:apple, :banana])
instance.fruit = [:apple, :banana]
```

The `assert` option adds a specific lambda validation:

```ruby
class Example
  include Otoroshi::Sanctuary

  property :quantity, Integer, assert: ->(v) { v > 0 }
end

# These examples raise an Otoroshi::AssertError
# with message: ":quantity does not respect the assertion"
Example.new(quantity: -1)
instance.quantity = -1
```

If property is an array, the `assert` is applied to each element.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :quantities, [Integer], assert: ->(v) { v > 0 }
end

# These examples raise an Otoroshi::OneOfError
# with message: ":quantity contains elements that do not respect the assertion"
Example.new(quantity: [1, -1])
instance.quantity = [1, -1]
```

The `allow_nil` option will define if `nil` is accepted as a value (default to `false`).

```ruby
class Example
  include Otoroshi::Sanctuary

  property :message, String, allow_nil: true


# Those examples won't raise any error
instance = Example.new
instance.message = nil
```

If property is an array, the `allow_nil` concerns the value itself, not the elements.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :messages, [String], allow_nil: true


# Those examples won't raise any error
instance = Example.new
instance.message = nil

# Those examples raise an Otoroshi::WrontTypeError
# with message: ":messages contains elements that are not instances of String"
instance = Example.new(messages: [nil])
instance.message = [nil]
```

The `default` option permits to define a default value, only on initialization if the key is not passed.

In case property is an array, it applies on the value itself, not on each element.

```ruby
class Example
  include Otoroshi::Sanctuary

  property :quantity, Integer, default: 0, allow_nil: true
end

instance = Example.new
instance.quantity # 0

instance = Example.new(quantity: nil)
instance.quantity # nil

instance.quantity = nil
instance.quantity # nil
```

## Refactor Example

### Before refactor

> 28 lines dedicated to properties

```ruby
class Importer
  attr_reader :file_path, :headers, :col_sep, :converters, :columns

  def initialize(file_path:, headers: false, col_sep: ',', converters: nil, columns: [])
    self.file_path = file_path
    self.headers = headers
    self.col_sep = col_sep
    self.converters = converters
    self.columns = columns
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

  def columns=(value)
    raise ArgumentError unless value.is_a?(Array) && value.all? { |elt| elt.is_a?(String) && elt.length > 3 }

    @columns = value
  end
end
```

### After refactor with Otoroshi

> 6 lines dedicated to properties

```ruby
class Importer
  include Otoroshi::Sanctuary

  property :file_path, String, assert: ->(v) { v.match? /.+\.csv/ }
  property :headers, one_of: [true, false], default: false
  property :col_sep, one_of: [',', ';', '\s', '\t', '|'], default: ','
  property :converters, one_of: [:integer, :float, :date], allow_nil: true
  property :columns, [String], assert: ->(v) { v.length > 3 }, default: []

  private

  # private business methods...
end
```
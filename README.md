# Otoroshi

![otoroshi](otoroshi.jpg "Otoroshi - Lance Red illustration")
> -- <cite>Illustration from [Lance Red](https://lancered_illustration.artstation.com/)</cite>

Otoroshis are legendary creatures in Japanese folklore and mythology. They act as guardian of holy temples.

The Otoroshi gem bring the `Sanctuary` class. Inherits from this class to easily define arguments validation.

## Define a new property

Use the `::property(name, type, options)` method.

* `name`: name of the property (symbol or string)
* `type`: the class the future value should belongs to (class or array of classes, `Object` by default)
* options:
  * `validate`: a custom validation to apply to the future value (lambda, `->(_) { true }` by default)
  * `allow_nil`: define if the future value can be set to nil (boolean, `false` by default)
  * `default`: the default value for this property (should match the required type, `nil` by default)

```ruby
class Importer < Otoroshi::Sanctuary
  property :file_path, String, validate: ->(v) { v.match? /.+\.csv/ }
  property :headers, [TrueClass, FalseClass], default: false
  property :col_sep, String, default: ','
  property :converters, Symbol, validate: ->(v) { v.in? %i[integer float date] }, allow_nil: true

  def call
    csv = CSV.parse(file_path, headers: headers, col_sep: col_sep, converters: converters)
    csv.each do |row|
      # ...
    end
  end
end
```

Getter and a setter are set for each property:

```ruby
class Example < Otoroshi::Sanctuary
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

Validations run on initialization and setting:

```ruby
class Example < Otoroshi::Sanctuary
  property :foo, Integer, ->(v) { v > 0 }
end

instance = Import.new # => ArgumentError, "foo does not match required type"
instance = Import.new(foo: 1.5) # => ArgumentError, "foo does not match required type"
instance = Import.new(foo: -1) # => ArgumentError, "foo does not match validation"

instance = Import.new(42) # no error
instance.foo = nil # => ArgumentError, "foo does not match required type"
instance.foo = 1.5 # => ArgumentError, "foo does not match required type"
instance.foo = -1 # => ArgumentError, "foo does not match validation"
```

Set `allow_nil` to `true` if `nil` is allowed:

```ruby
class Example < Otoroshi::Sanctuary
  property :foo, Integer, ->(v) { v > 0 }, allow_nil: true
end

instance = Import.new # no error

instance.foo = 42
instance.foo = nil  # no error
```

Set `default` to the default value. You can always set the value to `nil` if `allow_nil` is `true`.

```ruby
class Example < Otoroshi::Sanctuary
  property :foo, Integer, ->(v) { v > 0 }, default: 1, allow_nil: true
end

instance = Import.new # no error
instance.foo # 1

instance = Import.new(foo: nil) # no error
instance.foo # nil

instance.foo = nil  # no error
instance.foo # nil
```
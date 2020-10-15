# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require './lib/otoroshi'

# rubocop:disable Style/SymbolArray
describe Otoroshi::Sanctuary do
  let(:monkey) { Class.new.include(described_class) }

  # initialize => runs validations and sets values
  # setter => runs validations and sets values
  # getter => returns value

  describe '#initialize' do
    context 'when arguments are all valid' do
      it 'initializes an instance an set values' do
        expect(monkey.new).to be_a monkey
        monkey.property(:foo, Integer)
        instance = monkey.new(foo: 42)
        expect(instance).to be_a monkey
        expect(instance.instance_variable_get(:@foo)).to eq 42
      end
    end

    context 'when at least one argument is not valid' do
      it 'raises an error' do
        expect { monkey.new(42) }.to raise_error ArgumentError
        monkey.property(:foo, String)
        monkey.property(:bar, Integer)
        expect { monkey.new(foo: 'hello', bar: 'world') }.to raise_error Otoroshi::Error
      end
    end
  end

  describe '#<getter>' do
    it 'returns the instance variable value' do
      monkey.property(:foo, Integer)
      instance = monkey.new(foo: 42)
      expect(instance.foo).to eq 42
    end
  end

  describe '#<setter>' do
    before do
      monkey.property(:foo, Integer)
      monkey.property(:bar, [Integer])
    end
    let(:instance) { monkey.new(foo: 42, bar: [1]) }

    context 'when value is valid' do
      it 'sets the instance variable value' do
        instance.foo = 7
        expect(instance.instance_variable_get(:@foo)).to eq 7
        instance.bar = [2]
        expect(instance.instance_variable_get(:@bar)).to eq [2]
      end

      context 'when values is pushed with <<' do
        it 'sets the instance variable value' do
          instance.bar << 2
          expect(instance.instance_variable_get(:@bar)).to eq [1, 2]
        end
      end
    end

    context 'when value is not valid' do
      it 'sets the instance variable value' do
        expect { instance.foo = 1.5 }.to raise_error Otoroshi::Error
        expect { instance.bar = [1.5] }.to raise_error Otoroshi::Error
        expect(instance.instance_variable_get(:@foo)).to eq 42
      end

      context 'when values is pushed with <<' do
        it 'raises an error' do
          expect { instance.bar << 1.5 }.to raise_error Otoroshi::Error
        end
      end

      context 'when values is pushed with add' do
        it 'does not raise error' do
          expect { instance.bar << 1.5 }.to raise_error Otoroshi::Error
        end
      end
    end
  end

  describe 'type validation' do
    context 'when type is not set' do
      it 'accepts any value' do
        monkey.property(:foo)
        expect { monkey.new(foo: nil) }.not_to raise_error
        expect { monkey.new(foo: 42) }.not_to raise_error
        expect { monkey.new(foo: [1, 2, 3]) }.not_to raise_error
        expect { monkey.new(foo: Class.new.new) }.not_to raise_error
      end
    end

    context 'when type is a class' do
      it 'validates that value is an instance of the class' do
        monkey.property(:foo, Integer)
        expect { monkey.new(foo: 42) }.not_to raise_error
        expect { monkey.new(foo: 'hello') }.to raise_error Otoroshi::WrongTypeError, ':foo is not an instance of Integer'
        expect { monkey.new(foo: [42]) }.to raise_error Otoroshi::WrongTypeError, ':foo is not an instance of Integer'
        expect { monkey.new(foo: nil) }.to raise_error Otoroshi::WrongTypeError, ':foo is not an instance of Integer'
      end
    end

    context 'when type is an array' do
      it 'validates that value is an array' do
        monkey.property(:foo, [])
        expect { monkey.new(foo: []) }.not_to raise_error
        expect { monkey.new(foo: [1, 2, 3]) }.not_to raise_error
        expect { monkey.new(foo: 42) }.to raise_error Otoroshi::NotAnArray, ':foo is not an array'
      end

      context 'when the array contains a class' do
        it 'validates that each element of the collection is an instance of the class' do
          monkey.property(:foo, [Integer])
          expect { monkey.new(foo: []) }.not_to raise_error
          expect { monkey.new(foo: [42]) }.not_to raise_error
          expect { monkey.new(foo: [1, 2, 3]) }.not_to raise_error
          expect { monkey.new(foo: [nil]) }.to raise_error Otoroshi::WrongTypeError, ':foo contains elements that are not instances of Integer'
          expect { monkey.new(foo: [1, 1.5]) }.to raise_error Otoroshi::WrongTypeError, ':foo contains elements that are not instances of Integer'
        end
      end

      context 'when the array is empty' do
        it 'accepts any element of the collection' do
          monkey.property(:foo, [])
          expect { monkey.new(foo: []) }.not_to raise_error
          expect { monkey.new(foo: [nil]) }.not_to raise_error
          expect { monkey.new(foo: [1, Class.new.new]) }.not_to raise_error
        end
      end
    end

    context 'when allow_nil: is true' do
      it 'accepts nil as a value' do
        monkey.property(:foo, Integer, allow_nil: true)
        expect { monkey.new(foo: nil) }.not_to raise_error
        expect { monkey.new(foo: [nil]) }.to raise_error Otoroshi::WrongTypeError, ':foo is not an instance of Integer'
      end
    end

    describe '@edge case - inheritance' do
      it 'validates inherited type' do
        parent = Class.new
        child = Class.new(parent)
        expect(child < parent).to be true
        monkey.property(:foo, parent)
        expect(monkey.new(foo: child.new)).to be_a monkey
        monkey.property(:foo, child)
        expect { monkey.new(foo: parent.new) }.to raise_error Otoroshi::WrongTypeError, ":foo is not an instance of #{child}"
      end
    end
  end

  describe 'inclusion validation (one_of:)' do
    it 'validates that value is included is the accepted values' do
      monkey.property(:foo, one_of: [:apple, :pear])
      expect { monkey.new(foo: :apple) }.not_to raise_error
      expect { monkey.new(foo: :banana) }.to raise_error Otoroshi::NotAcceptedError, ':foo is not included in [:apple, :pear]'
    end

    context 'when type is an array with class' do
      it 'validates that each element is included is the accepted values' do
        monkey.property(:foo, [], one_of: [:apple, :pear])
        expect { monkey.new(foo: []) }.not_to raise_error
        expect { monkey.new(foo: [:apple, :pear]) }.not_to raise_error
        expect { monkey.new(foo: [:apple, :banana]) }.to raise_error Otoroshi::NotAcceptedError, ':foo contains elements that are not included in [:apple, :pear]'
      end
    end

    context 'when :allow_nil is true' do
      it 'accepts nil as a value' do
        monkey.property(:foo, one_of: [:apple, :pear], allow_nil: true)
        expect { monkey.new(foo: nil) }.not_to raise_error
      end
    end
  end

  describe 'specific validation (assert:)' do
    it 'validates that value respects the assertion' do
      monkey.property(:foo, Integer, assert: ->(v) { v > 0 })
      expect { monkey.new(foo: 42) }.not_to raise_error
      expect { monkey.new(foo: -1) }.to raise_error Otoroshi::AssertionError, ':foo does not respect the assertion'
    end

    context 'when type is an array' do
      it 'validates that each element respects the assertion' do
        monkey.property(:foo, [], assert: ->(v) { v > 0 })
        expect { monkey.new(foo: []) }.not_to raise_error
        expect { monkey.new(foo: [1, 2]) }.not_to raise_error
        expect { monkey.new(foo: [1, -1]) }.to raise_error Otoroshi::AssertionError, ':foo contains elements that do not respect the assertion'
      end
    end

    context 'when :allow_nil is true' do
      it 'accepts nil as a value' do
        monkey.property(:foo, one_of: [:apple, :pear], allow_nil: true)
        expect { monkey.new(foo: nil) }.not_to raise_error
      end
    end
  end
end

#     describe ':one_of (array of values)' do
#       context 'when :one_of is not set' do
#         it 'does not validate value inclusion' do
#           monkey.property(:foo)
#           expect { monkey.new(foo: :bar) }.not_to raise_error
#         end
#       end

#       context 'when :one_of is set' do
#         it 'validates that value is included in the accepted ones' do
#           monkey.property(:foo, one_of: [:apple, :pear])
#           # initialize
#           expect { monkey.new(foo: :apple) }.not_to raise_error
#           expect { monkey.new(foo: :banana) }.to raise_error Otoroshi::NotAcceptedError, ':foo is not included in [apple, pear]'
#           # set
#           instance = monkey.new(foo: :apple)
#           expect { instance.foo = :pear }.not_to raise_error
#           expect { instance.foo = :banana }.to raise_error Otoroshi::NotAcceptedError, ':foo is not included in [apple, pear]'
#         end

#         context 'when :array is true' do
#           it 'validates that each value is included in the accepted ones' do
#             monkey.property(:foo, array: true, one_of: [:apple, :pear])
#             # initialize
#             expect { monkey.new(foo: []) }.not_to raise_error
#             expect { monkey.new(foo: [:apple, :pear]) }.not_to raise_error
#             expect { monkey.new(foo: [:apple, :banana]) }.to raise_error Otoroshi::NotAcceptedError, ':foo contains elements that are not included in [apple, pear]'
#             # set
#             instance = monkey.new(foo: [:apple])
#             expect { instance.foo = [] }.not_to raise_error
#             expect { instance.foo = [:apple, :pear] }.not_to raise_error
#             expect { instance.foo = [:apple, :banana] }.to raise_error Otoroshi::NotAcceptedError, ':foo contains elements that are not included in [apple, pear]'
#           end
#         end
#       end
#     end

#     describe ':validate (Lambda, default: ->(_) { true })' do
#       context 'when :validate is not set' do
#         it 'does not validate value' do
#           monkey.property(:foo, Integer)
#           expect { monkey.new(foo: 1) }.not_to raise_error
#           expect { monkey.new(foo: -1) }.not_to raise_error
#         end
#       end

#       context 'when :validate has a lambda' do
#         it 'validates that value matches the lambda' do
#           monkey.property(:foo, Integer, validate: ->(v) { v > 0 })
#           # initialize
#           expect { monkey.new(foo: 1) }.not_to raise_error
#           expect { monkey.new(foo: -1) }.to raise_error Otoroshi::AssertionError, ':foo does not pass specific validation'
#           # set
#           instance = monkey.new(foo: 42)
#           expect { instance.foo = 7 }.not_to raise_error
#           expect { instance.foo = -7 }.to raise_error Otoroshi::AssertionError, ':foo does not pass specific validation'
#         end
#       end

#       context 'when :array is true' do
#         it 'validates that each value is included in the accepted ones' do
#           monkey.property(:foo, array: true, validate: ->(v) { v > 0 })
#           # initialize
#           expect { monkey.new(foo: []) }.not_to raise_error
#           expect { monkey.new(foo: [1, 2]) }.not_to raise_error
#           expect { monkey.new(foo: [1, -1]) }.to raise_error Otoroshi::AssertionError, ':foo contains elements that do not pass specific validation'
#           # set
#           instance = monkey.new(foo: [42])
#           expect { instance.foo = [] }.not_to raise_error
#           expect { instance.foo = [1, 2] }.not_to raise_error
#           expect { instance.foo = [1, -1] }.to raise_error Otoroshi::AssertionError, ':foo contains elements that do not pass specific validation'
#         end
#       end
#     end

#     describe ':allow_nil (true or false, default: false)' do
#       context 'when :allow_nil is not set or is set to false' do
#         it 'checks the value is present' do
#           monkey.property(:foo, Integer)
#           expect { monkey.new }.to raise_error ArgumentError
#         end
#       end

#       context 'when :allow_nil is true' do
#         it 'authorizes nil value' do
#           monkey.property(:foo, Integer, allow_nil: true)
#           expect { monkey.new }.not_to raise_error
#         end
#         it 'does not raise error on validation if value is nil' do
#           monkey.property(:foo, Integer, validate: ->(v) { v > 0 }, allow_nil: true)
#           expect { monkey.new }.not_to raise_error
#         end
#       end
#     end

#     describe ':default (default: nil)' do
#       context 'when :default is set' do
#         context 'when key is not provided on initialization' do
#           before { monkey.property(:foo, Integer, default: 0) }

#           it 'does not raise error' do
#             expect { monkey.new }.not_to raise_error
#           end
#           it 'uses the default value' do
#             expect(monkey.new.foo).to eq 0
#           end
#         end

#         context 'when value is explicitely initialized with nil' do
#           it 'does not use the default value' do
#             monkey.property(:foo, Integer, default: 0, allow_nil: true)
#             expect(monkey.new(foo: nil).foo).to eq nil
#           end
#         end

#         context 'when value is explicitely assigned to nil' do
#           it 'does not use the default value' do
#             monkey.property(:foo, Integer, default: 0, allow_nil: true)
#             instance = monkey.new(foo: 42)
#             instance.foo = nil
#             expect(instance.foo).to eq nil
#           end
#         end
#       end
#     end
#   end

#   describe '::properties' do
#     context 'when there is no properties' do
#       it 'returns an empty list' do
#         expect(monkey.properties).to be_empty
#       end
#     end

#     context 'when there is one property' do
#       it 'returns a list containing the property' do
#         monkey.property(:foo)
#         expect(monkey.properties).to eq({ foo: { allow_nil: false, default: nil } })
#       end
#     end

#     context 'when there is multiple properties' do
#       it 'returns a list containing all properties' do
#         monkey.property(:foo)
#         monkey.property(:bar, allow_nil: true, default: 0)
#         expect(monkey.properties).to eq(
#           {
#             foo: { allow_nil: false, default: nil },
#             bar: { allow_nil: true, default: 0 }
#           }
#         )
#       end
#     end
#   end
# end
# rubocop:enable Style/SymbolArray

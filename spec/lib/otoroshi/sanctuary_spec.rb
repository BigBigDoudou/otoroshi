# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Style/SymbolArray, Style/WordArray
describe Otoroshi::Sanctuary do
  let(:monkey) { Class.new.include(described_class) }

  # initialize => runs validations and sets values
  # setter => runs validations and sets values
  # getter => returns value

  describe '#initialize' do
    context 'when no properties are set' do
      it 'initializes an instance' do
        expect(monkey.new).to be_a monkey
      end
    end

    context 'when arguments are all valid' do
      before { monkey.property(:number, Integer) }

      it 'initializes an instance' do
        expect(monkey.new(number: 42)).to be_a monkey
      end

      it 'sets the instance variables values' do
        instance = monkey.new(number: 42)
        expect(instance.instance_variable_get(:@number)).to eq 42
      end
    end

    context 'when at least one argument is not valid' do
      it 'raises an error' do
        monkey.property(:message, String)
        monkey.property(:number, Integer)
        expect { monkey.new(message: 'hello', number: 'world') }.to raise_error Otoroshi::Error
      end
    end

    context 'when undefined keys are passed' do
      it 'raises an error' do
        monkey.property(:number, Integer)
        expect { monkey.new(message: 'hello') }.to raise_error ArgumentError
      end
    end
  end

  describe '#<getter>' do
    it 'returns the instance variable value' do
      monkey.property(:number, Integer)
      instance = monkey.new(number: 42)
      expect(instance.number).to eq 42
    end
  end

  describe '#<setter>' do
    context 'when value is expected to be a single object' do
      before { monkey.property(:number, Integer) }

      let(:instance) { monkey.new(number: 42) }

      context 'when value is valid' do
        it 'sets the instance variable value' do
          instance.number = 7
          expect(instance.instance_variable_get(:@number)).to eq 7
        end
      end

      context 'when value is not valid' do
        it 'raises an error' do
          expect { instance.number = 1.5 }.to raise_error Otoroshi::Error
        end
      end

      context 'when value is set using "+=" or "-="' do
        context 'when result is valid' do
          it 'sets the instance variable value' do
            instance.number += 8
            expect(instance.instance_variable_get(:@number)).to eq 50
          end
        end

        context 'when result is not valid' do
          it 'raises an error' do
            expect { instance.number += 0.5 }.to raise_error Otoroshi::Error
          end
        end
      end
    end

    context 'when value is expected to be collection' do
      before { monkey.property(:numbers, [Integer]) }

      let(:instance) { monkey.new(numbers: [1, 2, 3]) }

      context 'when value is valid' do
        it 'sets the instance variable value' do
          instance.numbers = [4, 5, 6]
          expect(instance.instance_variable_get(:@numbers)).to eq [4, 5, 6]
        end
      end

      context 'when value is not valid' do
        it 'raises an error' do
          expect { instance.numbers = ['hello', 'world'] }.to raise_error Otoroshi::Error
        end
      end
    end

    context 'when value is mutated' do
      context 'when value is not an array' do
        it 'raises an error' do
          monkey.property(:message, String)
          instance = monkey.new(message: 'hello')
          expect { instance.message.upcase! }.to raise_error FrozenError
        end
      end

      context 'when value is an array' do
        it 'raises an error' do
          monkey.property(:numbers, [Integer])
          instance = monkey.new(numbers: [1, 2, 3])
          expect { instance.numbers << 4 }.to raise_error FrozenError
        end
      end
    end
  end

  describe 'type validation' do
    context 'when type is not set' do
      before { monkey.property(:whatever) }

      it 'accepts nil value' do
        expect { monkey.new(whatever: nil) }.not_to raise_error
      end

      it 'accepts any single value' do
        expect { monkey.new(whatever: Class.new.new) }.not_to raise_error
      end

      it 'accepts any collection' do
        expect { monkey.new(whatever: [Class.new.new]) }.not_to raise_error
      end
    end

    context 'when type is another class than Array' do
      it 'validates value is an instance of the class' do
        monkey.property(:number, Integer)
        expect { monkey.new(number: 'hello') }
          .to raise_error Otoroshi::TypeError, ':number is not an instance of Integer'
      end
    end

    context 'when type is an array' do
      context 'when not specific class is set (property :whatevers, [])' do
        before { monkey.property(:whatevers, []) }

        it 'accepts empty array' do
          expect { monkey.new(whatevers: []) }.not_to raise_error
        end

        it 'validates value is an array' do
          expect { monkey.new(whatevers: 42) }.to raise_error Otoroshi::Collection::ArrayError, ':whatevers is not an array'
        end
      end

      context 'when the array specifies a class (property :numbers, [Integer])' do
        before { monkey.property(:numbers, [Integer]) }

        it 'accepts empty array' do
          expect { monkey.new(numbers: []) }.not_to raise_error
        end

        it 'validates each element of the collection is an instance of the class' do
          expect { monkey.new(numbers: [1, 1.5]) }
            .to raise_error Otoroshi::Collection::TypeError, ':numbers contains elements that are not instances of Integer'
        end
      end
    end

    describe 'inheritance' do
      let(:parent) { Class.new }
      let(:child) { Class.new(parent) }

      it 'accepts inherited classes' do
        monkey.property(:thing, parent)
        expect { monkey.new(thing: child.new) }.not_to raise_error
      end

      it 'does not accept ancestor classes' do
        monkey.property(:thing, child)
        expect { monkey.new(thing: parent.new) }.to raise_error Otoroshi::TypeError, ":thing is not an instance of #{child}"
      end
    end
  end

  describe 'inclusion validation (one_of:)' do
    it 'validates value is included is the accepted values' do
      monkey.property(:foo, one_of: [:apple, :pear])
      expect { monkey.new(foo: :banana) }
        .to raise_error Otoroshi::OneOfError, ':foo is not in [:apple, :pear]'
    end

    context 'when type is an array with class' do
      before { monkey.property(:foo, [], one_of: [:apple, :pear]) }

      it 'accepts empty array' do
        expect { monkey.new(foo: []) }.not_to raise_error
      end

      it 'validates each element is included is the accepted values' do
        expect { monkey.new(foo: [:apple, :banana]) }
          .to raise_error Otoroshi::Collection::OneOfError, ':foo contains elements that are not in [:apple, :pear]'
      end
    end

    context 'when :allow_nil is true' do
      it 'accepts nil as a value' do
        monkey.property(:foo, one_of: [:apple, :pear], allow_nil: true)
        expect { monkey.new(foo: nil) }.not_to raise_error
      end
    end
  end

  describe 'assertion validation (assert:)' do
    it 'validates value respects the assertion' do
      monkey.property(:foo, Integer, assert: ->(v) { v > 0 })
      expect { monkey.new(foo: -1) }
        .to raise_error Otoroshi::AssertError, ':foo does not respect the assertion'
    end

    context 'when type is an array' do
      before { monkey.property(:foo, [], assert: ->(v) { v > 0 }) }

      it 'accepts empty array' do
        expect { monkey.new(foo: []) }.not_to raise_error
      end

      it 'validates each element respects the assertion' do
        expect { monkey.new(foo: [1, -1]) }
          .to raise_error Otoroshi::Collection::AssertError, ':foo contains elements that do not respect the assertion'
      end
    end
  end

  describe 'allow nil as a value (allow_nil:)' do
    it 'permits null values' do
      monkey.property(:foo, Integer, allow_nil: true)
      expect { monkey.new }.not_to raise_error
    end

    it 'ignores inclusion and assertion' do
      monkey.property(:foo, Integer, one_of: [1, 2, 3], allow_nil: true)
      monkey.property(:bar, Integer, assert: ->(v) { v > 0 }, allow_nil: true)
      expect { monkey.new }.not_to raise_error
    end

    context 'when type is an array' do
      it 'does not apply to each element' do
        monkey.property(:foo, [Integer], allow_nil: true)
        expect { monkey.new(foo: [1, nil]) }
          .to raise_error Otoroshi::Collection::TypeError, ':foo contains elements that are not instances of Integer'
      end
    end
  end

  describe 'mutliple properties test' do
    before do
      monkey.property(:number, Integer)
      monkey.property(:numbers, [Integer])
      monkey.property(:message, String)
      monkey.property(:messages, [String])
    end

    let(:instance) { monkey.new(number: 42, numbers: [1, 2, 3], message: 'hello', messages: ['alfa', 'bravo', 'charlie']) }

    it 'defines setters for each properties' do # rubocop:disable RSpec/MultipleExpectations
      expect(instance.number).to eq 42
      expect(instance.numbers).to eq [1, 2, 3]
      expect(instance.message).to eq 'hello'
      expect(instance.messages).to eq ['alfa', 'bravo', 'charlie']
    end

    it 'defines getters for each properties' do # rubocop:disable RSpec/MultipleExpectations
      expect { instance.number = 7 }.to change(instance, :number).from(42).to(7)
      expect { instance.numbers = [4, 5, 6] }.to change(instance, :numbers).from([1, 2, 3]).to([4, 5, 6])
      expect { instance.message = 'world' }.to change(instance, :message).from('hello').to('world')
      expect { instance.messages = ['delta', 'echo', 'foxtrot'] }
        .to change(instance, :messages).from(['alfa', 'bravo', 'charlie']).to(['delta', 'echo', 'foxtrot'])
    end
  end

  describe 'dynamic default' do
    context 'when default is a dynamic value' do
      it 'does not actualize the value' do
        monkey.property(:time, default: Time.now)
        instance_a = monkey.new
        instance_b = monkey.new
        expect(instance_b.time).to eq instance_a.time
      end
    end
  end

  context 'when initialize is overrided' do
    before do
      monkey.property(:number, Integer, assert: ->(v) { v >= 0 }, default: 0)
      monkey.property(:message, String, allow_nil: true, default: '')
      monkey.property(:thing, allow_nil: false)
      monkey.define_method(:initialize) do |number: 42, message: nil, thing: nil|
        self.number = number
        self.message = message
        self.thing = thing
      end
    end

    let(:instance) { monkey.new }

    it 'overrides the default value' do
      expect(instance.number).to eq 42
    end

    it 'overrides default with nil' do
      expect(instance.message).to be_nil
    end

    it 'overrides falsy allow_nil with nil' do
      expect(instance.thing).to be_nil
    end

    it 'run validations' do
      expect { instance.number = -1 }.to raise_error Otoroshi::Error
    end
  end
end
# rubocop:enable Style/SymbolArray, Style/WordArray

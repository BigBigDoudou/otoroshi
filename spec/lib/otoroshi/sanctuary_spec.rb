# frozen_string_literal: true

require './lib/otoroshi/sanctuary'

describe Otoroshi::Sanctuary do
  let(:monkey) { Class.new(Otoroshi::Sanctuary) }

  describe '::property(name, type, :validate, :allow_nil, :default)' do
    describe 'name (Symbol, required)' do
      it 'defines a getter' do
        monkey.property(:foo)
        expect(monkey.new).to respond_to(:foo)
      end

      it 'defines a setter' do
        monkey.property(:foo)
        expect(monkey.new).to respond_to(:foo=)
      end
    end

    describe 'type (Class or array of Classes, default: Object)' do
      context 'when :type is not set or is set to nil' do
        it 'does not validate value type' do
          monkey.property(:foo)
          expect(monkey.new(foo: nil)).to be_a monkey
          expect(monkey.new(foo: 42)).to be_a monkey
          expect(monkey.new(foo: Class.new.new)).to be_a monkey
        end
      end

      context 'when :type is a Class' do
        before { monkey.property(:foo, Integer) }
        let(:instance) { monkey.new(foo: 42) }

        context 'when value matches the type' do
          it 'sets the value' do
            expect { monkey.new(foo: 42) }.not_to raise_error
            expect { instance.foo = 7 }.not_to raise_error
          end
        end

        context 'when value does not match the type' do
          it 'raises an error' do
            expect { monkey.new(foo: 'hello') }.to raise_error ArgumentError
            expect { instance.foo = false }.to raise_error ArgumentError
          end
        end
      end

      context 'when :type is an array' do
        before { monkey.property(:foo, [Symbol, String]) }
        let(:instance) { monkey.new(foo: :hello) }

        context 'when value matches one of the type' do
          it 'sets the value' do
            # initialize
            expect { monkey.new(foo: :hello) }.not_to raise_error
            expect { monkey.new(foo: 'hello') }.not_to raise_error
            # set
            expect { instance.foo = :hello }.not_to raise_error
            expect { instance.foo = 'hello' }.not_to raise_error
          end
        end

        context 'when value does not match any of the type' do
          it 'raises an error' do
            expect { monkey.new(foo: 42) }.to raise_error ArgumentError
            expect { instance.foo = 42 }.to raise_error ArgumentError
          end
        end
      end

      describe 'inheritance' do
        it 'validates inherited type' do
          parent = Class.new
          child = Class.new(parent)
          expect(child < parent).to be true
          monkey.property(:foo, parent)
          expect(monkey.new(foo: child.new)).to be_a monkey
          monkey.property(:bar, child)
          expect { monkey.new(foo: parent.new) }.to raise_error ArgumentError
        end
      end
    end

    describe ':validate (Lambda, default: ->(_) { true })' do
      context 'when :validate is not set' do
        it 'does not validate value' do
          monkey.property(:foo, Integer)
          expect { monkey.new(foo: 1) }.not_to raise_error
          expect { monkey.new(foo: -1) }.not_to raise_error
        end
      end

      context 'when :validate has a lambda' do
        it 'validates that value matches the lambda' do
          monkey.property(:foo, Integer, validate: ->(v) { v > 0 })
          # initialize
          expect { monkey.new(foo: 1) }.not_to raise_error
          expect { monkey.new(foo: -1) }.to raise_error ArgumentError
          # set
          instance = monkey.new(foo: 42)
          expect { instance.foo = 7 }.not_to raise_error
          expect { instance.foo = -7 }.to raise_error ArgumentError
        end
      end
    end

    describe ':allow_nil (true or false, default: false)' do
      context 'when :allow_nil is not set or is set to false' do
        it 'checks the value is present' do
          monkey.property(:foo, Integer)
          expect { monkey.new }.to raise_error ArgumentError
        end
      end

      context 'when :allow_nil is true' do
        it 'authorizes nil value' do
          monkey.property(:foo, Integer, allow_nil: true)
          expect { monkey.new }.not_to raise_error
        end
        it 'does not raise error on validation if value is nil' do
          monkey.property(:foo, Integer, validate: ->(v) { v > 0 }, allow_nil: true)
          expect { monkey.new }.not_to raise_error
        end
      end
    end

    describe ':default (default: nil)' do
      context 'when :default is set' do
        context 'when key is not provided on initialization' do
          before { monkey.property(:foo, Integer, default: 0) }

          it 'does not raise error' do
            expect { monkey.new }.not_to raise_error
          end
          it 'uses the default value' do
            expect(monkey.new.foo).to eq 0
          end
        end

        context 'when value is explicitely set to nil on initialization' do
          it 'does not use the default value' do
            monkey.property(:foo, Integer, default: 0, allow_nil: true)
            expect(monkey.new(foo: nil).foo).to eq nil
          end
        end

        context 'when value is explicitely set to nil on update' do
          it 'does not use the default value' do
            monkey.property(:foo, Integer, default: 0, allow_nil: true)
            instance = monkey.new(foo: 42)
            instance.foo = nil
            expect(instance.foo).to eq nil
          end
        end
      end
    end
  end

  describe '::properties' do
    context 'when there is no properties' do
      it 'returns an empty list' do
        expect(monkey.properties).to be_empty
      end
    end

    context 'when there is one property' do
      it 'returns a list containing the property' do
        monkey.property(:foo)
        expect(monkey.properties).to eq [:foo]
      end
    end

    context 'when there is multiple properties' do
      it 'returns a list containing all properties' do
        monkey.property(:foo)
        monkey.property(:bar)
        monkey.property(:zed)
        expect(monkey.properties).to match_array(%i[foo bar zed])
      end
    end
  end
end

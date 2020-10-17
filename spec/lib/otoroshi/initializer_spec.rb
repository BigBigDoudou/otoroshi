# frozen_string_literal: true

require 'spec_helper'

describe Otoroshi::Initializer do
  describe '::draw' do
    describe 'parameters' do
      it 'draws #initialize parameters' do
        properties = {
          number: { type: Integer, allow_nil: false, default: 0 },
          message: { type: String, allow_nil: true, default: nil }
        }
        expect(described_class.draw(properties)).to include 'number: 0, message: nil'
      end

      context 'when default is String' do
        it 'add quotes around the string' do
          properties = { message: { type: String, default: 'hello' } }
          expect(described_class.draw(properties)).to include 'message: "hello"'
        end
      end

      context 'when default is Symbol' do
        it 'add colon before the symbol' do
          properties = { message: { type: Symbol, default: :alfa } }
          expect(described_class.draw(properties)).to include 'message: :alfa'
        end
      end

      context 'when default is Time, DateTime or Date' do
        it '?' do
          timestamp = Time.now.to_s
          properties = { time: { type: Time, default: timestamp } }
          expect(described_class.draw(properties)).to include "time: \"#{timestamp}\""
        end
      end
    end
  end
end

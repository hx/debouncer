RSpec.describe Debouncer do
  it 'has a version number' do
    expect(Debouncer::VERSION).not_to be nil
  end

  it 'can be flushed from a reducer' do
    d = Debouncer.new(2)
    d.reducer 0 do |a, b|
      sum = a.first + b.first
      d.flush if sum > 10
      [sum]
    end
    result = nil
    d.debounce(nil, 4) { |x| result = x }
    expect(result).to be nil
    d.debounce(nil, 8) { |x| result = x }
    expect(result).to eq 12
  end

  it 'can be flushed by a limiter' do
    d = Debouncer.new(2)
    d.reducer(0) { |a, b| [a.first + b.first] }
    d.limiter { |a| a < 10 }
    result = nil
    d.debounce(nil, 4) { |x| result = x }
    expect(result).to be nil
    d.debounce(nil, 8) { |x| result = x }
    expect(result).to eq 12
  end
end

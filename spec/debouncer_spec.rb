RSpec.describe Debouncer do
  it 'has a version number' do
    expect(Debouncer::VERSION).not_to be nil
  end

  it 'can be flushed from a reducer' do
    result = nil
    d = Debouncer.new(2) { |x| result = x }
    d.reducer 0 do |a, b|
      sum = a.first + b.first
      d.flush! if sum > 10
      [sum]
    end
    d.call 4
    expect(d).to be_sleeping
    expect(result).to be nil
    d.call 8
    expect(d).not_to be_sleeping
    expect(result).to eq 12
  end

  it 'accepts a symbol as a reducer' do
    result = nil
    d = Debouncer.new(30) { |*args| result = args }
    d.reducer 3, :+
    d.call 4
    d.call 5
    d.flush!
    expect(result).to eq [3, 4, 5]

    result = nil
    d.reducer :|
    d.call :a
    d.call :b
    d.call :a
    d.call :c, :b, :a
    d.flush!
    expect(result.to_a).to eq [:a, :b, :c]
  end

  it 'can group calls' do
    results = []
    d = Debouncer.new(30) { |*args| results << args }
    d.group(:a).call :foo
    d.group(:b).call :bar
    expect(results).to eq []
    d.group(:b).flush!
    expect(results).to eq [[:bar]]
    d.group(:a).flush!
    expect(results).to eq [[:bar], [:foo]]
  end

  it 'can kill all slept threads' do
    d = Debouncer.new(5) { }
    d.call
    expect(d.sleeping?).to be 1
    d.group(:another).call
    expect(d.sleeping?).to be 2
    d.kill
    expect(d).not_to be_sleeping
  end
end

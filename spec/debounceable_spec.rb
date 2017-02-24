describe Debouncer::Debounceable do
  class SampleClass
    extend Debouncer::Debounceable

    attr_accessor :callback

    def run_callback(*args)
      callback.call *args
    end
    debounce :run_callback, 0.1,
             rescue_with: :show_ex,
             reduce_with: :reducer

    def self.show_ex(ex)
      puts "#{ex.class} #{ex.message}\n  #{ex.backtrace.join "\n  "}"
    end

    def reducer(old, new)
      sum = (old.first || 0) + new.first
      flush_run_callback unless sum < 10
      [sum]
    end
  end

  subject { SampleClass.new }

  it 'provides means to join background threads' do
    result = nil
    subject.callback = -> x { result = x }
    subject.run_callback 7
    expect(result).to be nil
    SampleClass.join_run_callback
    expect(result).to be 7
  end

  it 'can flush from within a reducer' do
    result = nil
    subject.callback = -> x { result = x }
    subject.run_callback 7
    expect(result).to be nil
    subject.run_callback 5
    expect(result).to be 12
  end
end

describe Debouncer::Debounceable do
  class SampleClass
    extend Debouncer::Debounceable

    attr_accessor :callback

    def run_callback
      callback.call
    end
    debounce :run_callback, 0.1, rescue_with: :show_ex

    def self.show_ex(ex)
      puts "#{ex.class} #{ex.message}\n #{ex.backtrace.join "\n  "}"
    end
  end

  it 'delays execution of a method' do
    fired = false
    sample = SampleClass.new
    sample.callback = -> { fired = true }
    sample.run_callback
    expect(fired).to be false
    SampleClass.join_run_callback
    expect(fired).to be true
  end
end

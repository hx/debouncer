class Debouncer
  class Group
    attr_reader :id, :debouncer

    def initialize(debouncer, id)
      @debouncer = debouncer
      @id        = id
    end

    def call(*args, &block)
      @debouncer.call_with_id @id, *args, &block
    end

    def to_proc
      method(:call).to_proc
    end

    def flush
      @debouncer.flush @id
    end

    def join
      @debouncer.join @id
    end

    def kill
      @debouncer.kill @id
    end
  end
end

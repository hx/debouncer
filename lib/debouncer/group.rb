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
      -> *args, &block { call *args, &block }
    end

    def flush
      @debouncer.flush @id
    end
  end
end

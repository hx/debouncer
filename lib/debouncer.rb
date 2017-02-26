require 'forwardable'

require 'debouncer/version'
require 'debouncer/group'

class Debouncer
  extend Forwardable

  DEFAULT_GROUP = Object.new

  attr_reader :delay

  def initialize(delay, &block)
    self.delay = delay
    raise ArgumentError, 'Expected a block' unless block
    @timeouts = {}
    @threads  = []
    @rescuers = {}
    @block    = block
    @lock     = Mutex.new
  end

  def delay=(delay)
    raise ArgumentError, "Expected Numeric, but got #{delay.class.name}" unless delay.is_a? Numeric
    @delay = delay
  end

  delegate arity: :@block

  def reducer(*initial, &block)
    @reducer = [initial, block || initial.pop]
    self
  end

  def rescuer(kind = StandardError, &block)
    @rescuers[kind] = block
    self
  end

  def group(id)
    Group.new self, id
  end

  def call(*args, &block)
    call_with_id DEFAULT_GROUP, *args, &block
  end

  def call_with_id(id, *args, &block)
    args << block if block
    thread = nil
    exclusively do
      thread        = @timeouts[id] ||= new_thread { begin_delay id }
      @flush        = [id]
      old_args      = thread[:args]
      thread[:args] =
          if @reducer
            initial, reducer = @reducer
            old_args ||= initial || []
            if reducer.is_a? Symbol
              old_args.__send__ reducer, args
            elsif reducer.respond_to? :call
              reducer.call old_args, args, id
            end
          else
            args.empty? ? old_args : args
          end
      if @flush == true
        thread.kill
        @timeouts.delete id
        @threads.delete thread
        @flush = false
      else
        thread[:run_at] = Time.now + @delay
      end
    end or
        run_block thread
    self
  end

  def flush(*args)
    if args.empty?
      if @lock.owned?
        @flush = true
      else
        flush @timeouts.keys.first while @timeouts.any?
      end
    else
      id = args.first
      if @lock.owned? && @flush == [id]
        @flush = true
      else
        dead = exclusively do
          if (thread = @timeouts.delete(id))
            thread.kill
            @threads.delete thread
          end
        end
        run_block dead if dead
      end
    end
    self
  end

  def join(kill_first = false)
    while (thread = exclusively { @threads.find &:alive? })
      thread.kill if kill_first
      thread.join
    end
    exclusively { [@threads, @timeouts].each &:clear } if kill_first
    self
  end

  def kill
    join true
  end

  def inspect
    "#<#{self.class}:0x#{'%014x' % (object_id << 1)} delay: #{@delay} timeouts: #{@timeouts.count} threads: #{@threads.count}>"
  end

  def to_proc
    -> *args, &block { call *args, &block }
  end

  def sleeping?
    @timeouts.length.nonzero?
  end

  private

  def begin_delay(id, &block)
    thread[:block] = block
    sleep @delay
    until exclusively { (thread[:run_at] <= Time.now).tap { |ready| @timeouts.delete id if ready } }
      sleep [thread[:run_at] - Time.now, 0].max
    end
    run_block thread
  rescue => ex
    @timeouts.reject! { |_, v| v == thread }
    (rescuer = @rescuers.find { |klass, _| ex.is_a? klass }) && rescuer.last[ex]
  ensure
    exclusively { @threads.delete thread }
  end

  def run_block(thread)
    @block.call *thread[:args]
  end

  def new_thread(*args, &block)
    Thread.new(*args, &block).tap { |t| @threads << t }
  end

  def exclusively(&block)
    @lock.synchronize &block
  end

  def thread
    Thread.current
  end
end

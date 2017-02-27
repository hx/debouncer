require 'debouncer'

class Debouncer
  module Debounceable
    SUFFIXES = {
        '?' => '_predicate',
        '!' => '_dangerous',
        '=' => '_assignment'
    }
    def debounce(name, delay, rescue_with: nil, grouped: false, reduce_with: nil, class_method: false)
      name =~ /^(\w+)([?!=]?)$/ or
          raise ArgumentError, 'Invalid method name'

      base_name = $1
      suffix    = $2
      immediate = "#{base_name}_immediately#{suffix}"
      debouncer = "@#{base_name}#{SUFFIXES[suffix]}_debouncer"
      extras    = ''
      extras    << ".reducer { |old, new| self.#{reduce_with} old, new }" if :reduce_with
      extras    << ".rescuer { |ex| self.#{rescue_with} ex }" if :rescue_with

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        #{'class << self' if class_method}
      
        alias_method :#{immediate}, :#{name}

        def #{name}(*args, &block)
          #{debouncer} ||= ::Debouncer.new(#{delay}) { |*args| self.#{immediate} *args }#{extras}
          #{debouncer}#{'.group(args.first)' if grouped}.call *args, &block
        end

        def flush_#{name}(*args)
          #{debouncer}.flush *args if #{debouncer}
        end

        def join_#{name}(*args)
          #{debouncer}.join *args if #{debouncer}
        end

        def cancel_#{name}(*args)
          #{debouncer}.kill *args if #{debouncer}
        end

        #{'end' if class_method}
      RUBY
    end

    def mdebounce(name, delay, **opts)
      debounce name, delay, class_method: true, **opts
    end
  end
end

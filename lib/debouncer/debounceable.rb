require 'debouncer'

class Debouncer
  module Debounceable
    def debounce(name, delay, rescue_with: nil, group_by: :object_id)
      name =~ /^(\w+)([?!=]?)$/ or
          raise ArgumentError, 'Invalid method name'

      base_name = $1
      suffix    = $2
      immediate = "#{base_name}_immediately#{suffix}"

      debouncer_for_method name, delay do |d|
        d.rescuer do |ex|
          case rescue_with
            when Symbol
              __send__ rescue_with, ex
            when Proc
              rescue_with[ex]
            else
              # Silent failure
          end
        end
      end

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        alias_method :#{immediate}, :#{name}

        def #{name}(*args)
          self.class.debouncer_for_method(:#{name}).debounce(#{group_by}, *args) { |*args| #{immediate} *args }
        end

        def self.join_#{name}
          debouncer_for_method(:#{name}).join
        end
      RUBY
    end

    def debouncer_for_method(name, delay = 0, &block)
      @method_debouncers       ||= {}
      @method_debouncers[name] ||= Debouncer.new(delay, &block)
    end
  end
end

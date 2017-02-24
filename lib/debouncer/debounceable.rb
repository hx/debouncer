require 'debouncer'

class Debouncer
  module Debounceable
    def debounce(name, delay, rescue_with: nil, group_by: :object_id, reduce_with: nil)
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
        end if rescue_with

        d.reducer do |old, args, id|
          case reduce_with
            when Symbol
              debouncing_instances(name)[id].__send__ reduce_with, old, args
            when Proc
              reduce_with[old, args, id]
            else
              raise ArgumentError
          end
        end if reduce_with
      end

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        alias_method :#{immediate}, :#{name}

        def #{name}(*args)
          id                 = #{group_by}
          instance_cache     = #{self.name}.debouncing_instances(:#{name})
          instance_cache[id] = self
          #{self.name}.debouncer_for_method(:#{name}).debounce(id, *args) { |*args| #{immediate} *args }
          instance_cache.delete id
        end

        def flush_#{name}
          #{self.name}.debouncer_for_method(:#{name}).flush #{group_by}
        end

        def self.join_#{name}
          debouncer_for_method(:#{name}).join
        end

        def self.cancel_#{name}
          debouncer_for_method(:#{name}).kill
        end
      RUBY
    end

    def debouncer_for_method(name, delay = 0, &block)
      (@method_debouncers ||= {})[name] ||= Debouncer.new(delay, &block)
    end

    def debouncing_instances(name)
      (@debouncing_instances ||= {})[name] ||= {}
    end
  end
end

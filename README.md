# Debouncer [![Build Status](https://travis-ci.org/hx/debouncer.svg?branch=master)](https://travis-ci.org/hx/debouncer)

Background thread debouncing for Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'debouncer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install debouncer

## Usage

### The easy way

Generally all you want to do is debounce an instance or class method. The `Debounceable` module gives you everything you need to get your bouncing methods debounced.

```ruby
require 'debouncer/debounceable'

class DangerZone
  extend Debouncer::Debounceable
  
  def send_warning
    system "echo We are about to get crazy! | wall"
  end
  
  debounce :send_warning, 2
end
```

Each call to `send_warning` will be delayed on a background thread for 2 seconds before firing. If, during those two seconds, it's called again, the count-down will restart, and only one warning will actually be sent.

If you want to send your warning immediately, your original method has been given a suffix so you can still access it:

```ruby
DangerZone.new.send_warning_immediately
```

A couple of methods have also been added to help work with background threads:

```ruby
dz = DangerZone.new

dz.join_send_warning   # Wait for all warnings to be sent
dz.flush_send_warning  # Send warnings immediately if any are waiting
dz.cancel_send_warning # Cancel all waiting warnings
```

You can also debounce your calls in groups. By setting the `grouped: true` option, the first argument passed to the debounced method will be used to create a separate debouncer thread.
 
```ruby
class DangerZone
  extend Debouncer::Debounceable
  
  def send_warning(message)
    system "echo #{message.shellescape} | wall"
  end
  
  debounce :send_warning, 2, grouped: true
end
```

Now, each unique message will have its own separate timeout. You can also pass group identifiers to `join_`, `flush_`, and `cancel_` methods to affect only those groups.

Arguments are always passed to your original method intact, and by default, the last set of arguments in a group wins. If the example above didn't use grouping:

```ruby
d = DangerZone.new
d.send_warning "We're going down!"
d.send_warning "Spiders are attacking!"
```

The first warning would be replaced by the second when the method is eventually run.

You can combine arguments to produce an end result however you like, using a reducer:

```ruby
class DangerZone
  extend Debouncer::Debounceable
  
  def send_warning(*messages)
    system "echo #{messages.map(&:shellescape).join ';'} | wall"
  end
  
  debounce :send_warning, 2, reduce_with: :combine_messages
  
  def combine_messages(memo, messages)
    memo + messages
  end
end
```

The `combine_messages` method will be called whenever `send_warning` is called. The first argument is the last value it returned, or an empty array if this is the first call for the thread. The second argument is an array of the arguments supplied to `send_warning`. It should return an array of arguments that will ultimately be passed to the original method.

If grouping is enabled, the first two arguments will not include the ID. Instead, it will be passed as the first argument. The reducer should not include the ID in the array it returns.

A reducer method is a good place to call `flush_*` if you hit some sort of limit or threshold. Just remember to still return the array of arguments you want to call.

```ruby
def combine_messages(memo, messages)
  result = memo + messages
  flush_send_warning if result.length >= 5
  result
end
```

Finally, you can also debounce class/module methods using the `mdebounce` method. If you want to combine calls on various instances of a class, a sound pattern is to debounce a class method and have instances call it. For example, consider broadcasting data changes to browsers, where you want to group changes to the same model together into single broadcasts:

```ruby
class Record
  extend Debouncer::Debounceable
  
  def self.broadcast(record_id)
    look_up(record_id).broadcast
  end
  
  mdebounce :broadcast, 0.5, grouped: true
   
  def save
    write_to_database
    Record.broadcast id
  end
end
```

In a web application, it's common for several instances of a model representing the same data record to existing during the course of a request. Debouncing the `broadcast` method on the instance wouldn't be effective, since each instance would have its own debouncer. By using a debounced class method, records are grouped by their ID instead of the Ruby objects that represent them.

### The clean(er) way

Under the hood, the `Debounceable` module uses a `Debouncer` instance as a thread controller. If you prefer not to have any extra methods defined on your class, you can use a `Debouncer` instance to achieve the same results.

```ruby
require 'debouncer'

d = Debouncer.new(2) { |message| puts message }
d.call 'I have arrived'
```

This will print the message "I have arrived!" after 2 seconds.

Grouping is simple with a debouncer:

```ruby
d.group(:warnings).call 'I am about to arrive...'
d.group(:alerts).call 'I have arrived!'
d.group(:alerts).flush
```

When adding an argument reducer, you can also specify an initial value:

```ruby
d = Debouncer.new(2) { |*messages| puts messages }
d.reducer('Here are some messages:', '') { |memo, messages| memo + messages }
d.call "Evented Ruby isn't so bad"
d.call "And it's threaded, too!"
```

After 2 seconds, the above code will print:

```text
Here are some messages:

Evented Ruby isn't so bad
And it's threaded, too!
```

If your reducer simply adds or OR's two arrays together, you can use a symbol instead:

```ruby
d.reducer 'Here are some messages:', '', :+
```

This will have the same result as the block form. If you use `:|` instead of `:+`, it will be like `memo | messages`, so messages won't be repeated between calls.

Methods like `flush`, `kill`, and `join` are available too, and to exactly what you'd expect. You can call them directly on your debouncer, or after a `group(id)` call if you want to target a specific group.

```ruby
# These lines are equivalent:
d.join :messages
d.group(:messages).join

# This will join all threads:
d.join
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hx/debouncer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

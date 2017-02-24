# Debouncer

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

### The agnostic way

Make yourself a debouncer with a fixed delay:

```ruby
require 'debouncer'
d = Debouncer.new(0.5) # Half a second
```

Hammer it as hard as you can:

```ruby
5.times { d.debounce { puts 'Hello!' } }
sleep 1
```

You'll see "Hello!" after half a second. Debounced code runs on background threads, so without `sleep 1`, the program exits immediately and you don't get any output.

A single debouncer is meant to serve an entire collection of consumers, so a unique thread is spawned for each identifier passed as the first argument to `debounce`:

```ruby
%w(Goodbye Hello Goodbye).each { |word| sleep(0.1) && d.debounce(word) { puts word } }
sleep 1
```

The above will output `Hello` and then `Goodbye`, because the second 'Goodbye' replaces the first, but the 'Hello' in the middle is on its own thread.

Subsequent arguments are passed to the block when it runs:

```ruby
d.debounce nil, 'hello' do |word|
  puts word
end
sleep 1
```

You can use a *reducer* to combine the arguments of multiple calls into a single argument. The `reducer` method accepts 0 or more initial arguments, and yields two arguments whenever it receives a new set of args; the last return value of the block (or an array of the initial value if it's running for the first time), and an array of arguements passed to `debounce` (without the first ID argument). The block should return an array of arguments that is ultimately passed to the callback. 

```ruby
d.reducer('The') { |last_result, args| last_result + args }
callback = -> *words { puts words.join(' ') }
d.debounce nil, 'quick', 'brown', &callback
d.debounce nil, 'fox', &callback
sleep 1
```

You guessed it; `The quick brown fox` will be your eventual output. Because you're working with arrays inside your reducer, parentheses can be your friends if you're expecting a fixed number of arguments each time:

```ruby
d.reducer(0) { |(sum), (value)| [sum + value] }
```

If your debouncer is handling an accumulation of data (say building bulk insert queries or writing logs), you can force it to stop waiting and fire immediately, either from within your reducer or on your main thread:

```ruby
d.reducer Set.new do |(query_set), (query)|
  query_set << query
  d.flush if query_set.length >= 100
  [query_set]
end
d.debounce(table.name, query) { |query_set| table.run_queries query_set }
d.flush table.name if query.very_important?
```

Both uses of `flush` in the example above will only flush the thread for that table. If you call `flush` outside your reducer and without an ID, the debouncer will flush every waiting thread.

The Ruby norm is for uncaught exceptions on background threads to fail silently. If you need to know what's going on back there (and you generally do), you can set yourself a *rescuer*:

```ruby
d.rescuer { |ex| STDERR.puts "#{ex.name} #{ex.message}\n  #{ex.backtrace.join "\n  "}" }
```

You can specify multiple rescuers for different exception types;

```ruby
d.rescuer(MinorError) { |ex| Logger.info ex.message }
d.rescuer(RuntimeError) { |ex| puts ex.message }
```

If you like DSLs, you can set up reducers and rescuers when you make your debouncer:

```ruby
debouncer = Debouncer.new 0.5 do
  rescuer { |ex| puts ex }
  reducer { |a, b| a + b }
end

# Or if you need your scope:
debouncer = Debouncer.new 0.5 do |d|
  d.rescuer { |ex| puts ex }
  d.reducer { |a, b| a + b }
end
```

Most debouncer methods return `self`, so you can also do most things with chaining:

```ruby
debouncer = Debouncer.new(3).
  rescuer { |ex| puts ex }.
  reducer { |a, b| a + b }.
  debounce { puts 'Look at all this stuff I chained together'}.
  flush # Ok you'd never really do this :P
```

Finally, when writing specs etc you occasionally need to wait for your background threads and/or kill them off. `#join` and `#kill` should give you everything you need. For example, in RSpec:

```ruby
subject { MyClass.new }

it 'does what I want' do
  subject.thing_that_is_debounced
  MyClass.debouncer.join
  expect(subject.thing).to be_done
end

after { MyClass.debouncer.kill } # Stop any debounced threads from rolling into the next example
```

### The easy way

Generally, you just have an instance method you want to debounce. For this, we have `Debounceable`, which uses a `Debouncer` instance behind the scenes.

```ruby
class Controller
  extend Debouncer::Debounceable
  
  def send_warning
    system "echo We are about to get crazy! | wall"
  end
  
  debounce :send_warning, 2
end
```

This ensures we're not broadcasting our message more frequently than every 2 seconds.

All the features of `Debouncer` are available through generated methods:

```ruby
class LogWriter
  extend Debouncer::Debounceable
  
  def write_lines(lines)
    Log.write_lines lines
  end
  
  debounce :write_lines, 2, 
           reduce_with: :combine_lines, 
           rescue_with: :handle_exception
           
  def combine_lines(current, new)
    [current.first + new.first].tap do |result|
      flush_write_lines if result.first.length >= 50
    end
  end
end
```

> TODO explain the rest

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hx/debouncer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

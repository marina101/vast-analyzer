## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vast_analyzer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vast_analyzer

## Usage

Simply pass your xml vast url to the parser object to instantiate a parser linked to that vast:

```ruby
parser = VastAnalyzer::Parser.new('https://www.vastexample.xml')
```

To categorize whether your vast contiains vpaid, flash, and/or js, simply call `categorize` on it:

```ruby
parser.categorize[:vpaid_status]
```

It will return one of four possible options: 'flash_js_vpaid', 'flash_vpaid', 'js_vpaid', 'neither'

Initializing a parser or calling categorize may also return an error subtype of the Error class if there is a problem with the url or the wrapper redirect url, if its not a vast link, or if the wrapper redirects more than five times.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You must also run `git submodule init` and `git submodule update` to initialize the submodules, that work with rubocop. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. 

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/adgear/vast-analyzer.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


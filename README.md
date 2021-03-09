# Business

[![Gem version](https://badge.fury.io/rb/business.svg)](http://badge.fury.io/rb/business)
[![CircleCI](https://circleci.com/gh/gocardless/business.svg?style=svg)](https://circleci.com/gh/gocardless/business)

Date calculations based on business calendars.

- [v2.0.0 breaking changes](#v200-breaking-changes)
- [Getting Started](#getting-started)
  - [Creating a calendar](#creating-a-calendar)
  - [Using a calendar file](#use-a-calendar-file)
- [Checking for business days](#checking-for-business-days)
- [Business day arithmetic](#business-day-arithmetic)
- [But other libraries already do this](#but-other-libraries-already-do-this)
- [License & Contributing](#license--contributing)

## v2.0.0 breaking changes

We have removed the bundled calendars as of version 2.0.0, if you need the calendars that were included:

- Download the calendars you wish to use from [v1.18.0](https://github.com/gocardless/business/tree/b12c186ca6fd4ffdac85175742ff7e4d0a705ef4/lib/business/data)
- Place them in a suitable directory in your project, typically `lib/calendars`
-  Add this directory path to your instance of `Business::Calendar` using the `load_paths` method.dd the directory to where you placed the yml files before you load the calendar

```ruby
Business::Calendar.load_paths = ["lib/calendars"] # your_project/lib/calendars/ contains bacs.yml
Business::Calendar.load("bacs")
```

If you wish to stay on the last version that contained bundled calendars, pin `business` to `v1.18.0`

```ruby
# Gemfile
gem "business", "v1.18.0"
```

## Getting started

To install business, simply:

```bash
gem install business
```

If you are using a Gemfile:

```ruby
gem "business", "~> 2.0"
```

### Creating a calendar

Get started with business by creating an instance of the calendar class, that accepts a hash that specifies which days of the week are considered working days, which days are holidays and which are extra working dates.

Additionally each calendar instance can be given a name. This can come in handy if you use multiple calendars.

```ruby
calendar = Business::Calendar.new(
  name: 'my calendar',
  working_days: %w( mon tue wed thu fri ),
  holidays: ["01/01/2014", "03/01/2014"],    # array items are either parseable date strings, or real Date objects
  extra_working_dates: [nil], # Makes the calendar to consider a weekend day as a working day.
)
```

### Use a calendar file

Defining a calendar as a Ruby object may not be convenient, so we provide a way of defining these calendars as YAML. Below we will walk through the necessary [steps](#example-calendar) to build your first calendar. All keys are optional and will default to the following:

Note: Elements of `holidays` and `extra_working_dates` may be either strings that `Date.parse()` [can understand](https://ruby-doc.org/stdlib-2.7.1/libdoc/date/rdoc/Date.html#method-c-parse), or `YYYY-MM-DD` (which is considered as a Date by Ruby YAML itself)[https://github.com/ruby/psych/blob/6ec6e475e8afcf7868b0407fc08014aed886ecf1/lib/psych/scalar_scanner.rb#L60].

#### YAML file Structure

```yml
working_days: # Optional, default [Monday-Friday]
  -
holidays: # Optional, default: []  ie: "no holidays" assumed
  -
extra_working_dates: # Optional, default: [], ie: no changes in `working_days` will happen
  -
```

#### Example calendar

```yaml
# lib/calendars/my_calendar.yml
working_days:
  - Monday
  - Wednesday
  - Friday
holidays:
  - 1st April 2020
  - 2021-04-01
extra_working_dates:
  - 9th March 2020 # A Saturday
```

Ensure the calendar file is saved to a directory that will hold all your calendars, typically `lib/calendars`, then add this directory to your instance of `Business::Calendar` using the `load_paths` method before you call your calendar.

`load_paths` also accepts an array of plain Ruby hashes with the format:

```ruby
  { "calendar_name" => { "working_days" => [] }
```

#### Example loading both a path and ruby hashes

```ruby
Business::Calendar.load_paths = [
  "lib/calendars",
  { "foo_calendar" => { "working_days" => ["monday"] } },
  { "bar_calendar" => { "working_days" => ["sunday"] } },
]
```

Now you can load the calendar by calling the `Business::Calendar.load(calendar_name)`. In order to avoid parsing the calendar file multiple times, there is a `Business::Calendar.load_cached(calendar_name)` method that caches the calendars by name after loading them.

```ruby
calendar = Business::Calendar.load("my_calendar") # lib/calendars/my_calendar.yml
calendar = Business::Calendar.load("foo_calendar")
# or
calendar = Business::Calendar.load_cached("my_calendar")
calendar = Business::Calendar.load_cached("foo_calendar")
```

## Checking for business days

To check whether a given date is a business day (falls on one of the specified working days or working dates, and is not a holiday), use the `business_day?` method on `Business::Calendar`.

```ruby
calendar.business_day?(Date.parse("Monday, 9 June 2014"))
# => true
calendar.business_day?(Date.parse("Sunday, 8 June 2014"))
# => false
```

More specifically you can check if a given `business_day?` is either a `working_day?` or a `holiday?` using methods on `Business::Calendar`.

```ruby
# Assuming "Monday, 9 June 2014" is a holiday
calendar.working_day?(Date.parse("Monday, 9 June 2014"))
# => true
calendar.holiday?(Date.parse("Monday, 9 June 2014"))
# => true
# Monday is a working day, but we have a holiday so it's not
# a business day
calendar.business_day?(Date.parse("Monday, 9 June 2014"))
# => false
```

## Business day arithmetic

The `add_business_days` and `subtract_business_days` are used to perform business day arithmetic on dates.

```ruby
date = Date.parse("Thursday, 12 June 2014")
calendar.add_business_days(date, 4).strftime("%A, %d %B %Y")
# => "Wednesday, 18 June 2014"
calendar.subtract_business_days(date, 4).strftime("%A, %d %B %Y")
# => "Friday, 06 June 2014"
```

The `roll_forward` and `roll_backward` methods snap a date to a nearby business day. If provided with a business day, they will return that date. Otherwise, they will advance (forward for `roll_forward` and backward for `roll_backward`) until a business day is found.

```ruby
date = Date.parse("Saturday, 14 June 2014")
calendar.roll_forward(date).strftime("%A, %d %B %Y")
# => "Monday, 16 June 2014"
calendar.roll_backward(date).strftime("%A, %d %B %Y")
# => "Friday, 13 June 2014"
```

To count the number of business days between two dates, pass the dates to `business_days_between`. This method counts from start of the first date to start of the second date. So, assuming no holidays, there would be two business days between a Monday and a Wednesday.

```ruby
date = Date.parse("Saturday, 14 June 2014")
calendar.business_days_between(date, date + 7)
# => 5
```

## But other libraries already do this

Another gem, [business_time](https://github.com/bokmann/business_time), also exists for this purpose. We previously used business_time, but encountered several issues that prompted us to start business.

Firstly, business_time works by monkey-patching `Date`, `Time`, and `FixNum`. While this enables syntax like `Time.now + 1.business_day`, it means that all configuration has to be global. GoCardless handles payments across several geographies, so being able to work with multiple working-day calendars is
essential for us. Business provides a simple `Calendar` class, that is initialized with a configuration that specifies which days of the week are considered to be working days, and which dates are holidays.

Secondly, business_time supports calculations on times as well as dates. For our purposes, date-based calculations are sufficient. Supporting time-based calculations as well makes the code significantly more complex. We chose to avoid this extra complexity by sticking solely to date-based mathematics.

<p align="center"><img src="http://3.bp.blogspot.com/-aq4iOz2OZzs/Ty8xaQwMhtI/AAAAAAAABrM/-vn4tcRA9-4/s1600/daily-morning-awesomeness-243.jpeg" alt="I'm late for business" width="250"/></p>

## License & Contributing
- business is available as open source under the terms of the [MIT License](LICENSE).
- Bug reports and pull requests are welcome on GitHub at https://github.com/gocardless/business.

GoCardless ♥ open source. If you do too, come [join us](https://gocardless.com/about/jobs).

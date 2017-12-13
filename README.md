# Business

[![Gem version](https://badge.fury.io/rb/business.svg)](http://badge.fury.io/rb/business)
[![Build status](https://travis-ci.org/gocardless/business.svg?branch=master)](https://travis-ci.org/gocardless/business)

Date calculations based on business calendars.

## Documentation

To get business, simply:

```bash
$ gem install business
```

### Getting started

Get started with business by creating an instance of the calendar class,
passing in a hash that specifies with days of the week are considered working
days, and which days are holidays.

```ruby
calendar = Business::Calendar.new(
  working_days: %w( mon tue wed thu fri ),
  holidays: ["01/01/2014", "03/01/2014"],    # array items are either parseable date strings, or real Date objects
  working_dates: ["08/01/2014"]
)
```

`working_dates` parameter makes the calendar to consider a weekend day as a working day.

A few calendar configs are bundled with the gem (see `lib/business/data` for
details). Load them by calling the `load` class method on `Calendar`. The
`load_cached` variant of this method caches the calendars by name after loading
them, to avoid reading and parsing the config file multiple times.

```ruby
calendar = Business::Calendar.load("weekdays")
calendar = Business::Calendar.load_cached("weekdays")
```

Config files are YAML files that look such simple as:
```yaml
working_days:
  - monday
  - tuesday
  - wednesday
  - thursday
  - friday

holidays:
  - January 1st, 2017
  - March 8th, 2017
  - May 1st, 2017

working_dates:
  - January 8st, 2017
```

If `working_days` is missing, then common default is used (mon-fri).
If `holidays` is missing, "no holidays" assumed.
If `working_dates` is missing, then no changes in `working_days` will happen.

Elements of `holidays` and `working_dates` may be
eiter strings that `Date.parse()` can understand,
or YYYY-MM-DD (which is considered as a Date by Ruby YAML itself).

```yaml
working_dates:
  - 2017-01-08  # Same as January 8th, 2017
```

You may find a few sample config files in `lib/business/data/` directory.

### Checking for business days

To check whether a given date is a business day (falls on one of the specified
working days, and is not a holiday), use the `business_day?` method on
`Calendar`.

```ruby
calendar.business_day?(Date.parse("Monday, 9 June 2014"))
# => true
calendar.business_day?(Date.parse("Sunday, 8 June 2014"))
# => false
```

### Custom calendars

To use a calendar you've written yourself, you need to add the directory it's
stored in as an additional calendar load path:

```ruby
Business::Calendar.additional_load_paths = ['path/to/your/calendar/directory']
```

You can then load the calendar as normal.

### Business day arithmetic

The `add_business_days` and `subtract_business_days` are used to perform
business day arithemtic on dates.

```ruby
date = Date.parse("Thursday, 12 June 2014")
calendar.add_business_days(date, 4).strftime("%A, %d %B %Y")
# => "Wednesday, 18 June 2014"
calendar.subtract_business_days(date, 4).strftime("%A, %d %B %Y")
# => "Friday, 06 June 2014"
```

The `roll_forward` and `roll_backward` methods snap a date to a nearby business
day. If provided with a business day, they will return that date. Otherwise,
they will advance (forward for `roll_forward` and backward for `roll_backward`)
until a business day is found.

```ruby
date = Date.parse("Saturday, 14 June 2014")
calendar.roll_forward(date).strftime("%A, %d %B %Y")
# => "Monday, 16 June 2014"
calendar.roll_backward(date).strftime("%A, %d %B %Y")
# => "Friday, 13 June 2014"
```

To count the number of business days between two dates, pass the dates to
`business_days_between`. This method counts from start of the first date to
start of the second date. So, assuming no holidays, there would be two business
days between a Monday and a Wednesday.

```ruby
date = Date.parse("Saturday, 14 June 2014")
calendar.business_days_between(date, date + 7)
# => 5
```

## But other libraries already do this

Another gem, [business_time](https://github.com/bokmann/business_time), also
exists for this purpose. We previously used business_time, but encountered
several issues that prompted us to start business.

Firstly, business_time works by monkey-patching `Date`, `Time`, and `FixNum`.
While this enables syntax like `Time.now + 1.business_day`, it means that all
configuration has to be global. GoCardless handles payments across several
geographies, so being able to work with multiple working-day calendars is
essential for us. Business provides a simple `Calendar` class, that is
initialized with a configuration that specifies which days of the week are
considered to be working days, and which dates are holidays.

Secondly, business_time supports calculations on times as well as dates. For
our purposes, date-based calculations are sufficient. Supporting time-based
calculations as well makes the code significantly more complex. We chose to
avoid this extra complexity by sticking solely to date-based mathematics.


![I'm late for business](http://3.bp.blogspot.com/-aq4iOz2OZzs/Ty8xaQwMhtI/AAAAAAAABrM/-vn4tcRA9-4/s1600/daily-morning-awesomeness-243.jpeg)

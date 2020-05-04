# Business

[![Gem version](https://badge.fury.io/rb/business.svg)](http://badge.fury.io/rb/business)
[![CircleCI](https://circleci.com/gh/gocardless/business.svg?style=svg)](https://circleci.com/gh/gocardless/business)

Date calculations based on business calendars.

## Documentation

To get business, simply:

```bash
$ gem install business
```

## Important: 2.0.0 breaking changes

We have removed the bundled calendars as of version 2.0.0, if you need the calendars that were included:

Download the calendars you wish to use from [before version 2](https://github.com/gocardless/business/tree/b12c186ca6fd4ffdac85175742ff7e4d0a705ef4/lib/business/data) and place them in a suitable place in your project.

Then, add the directory to where you placed the yml files before you load the calendar:

```ruby
Calendar::Business.load_paths("lib/calendars") # your_project/lib/calendars/ contains bacs.yml
Calendar::Business.load("bacs")
```

### Getting started

Get started with business by creating an instance of the calendar class, passing in a hash that specifies with days of the week are considered working days, and which days are holidays.

```ruby
calendar = Business::Calendar.new(
  working_days: %w( mon tue wed thu fri ),
  holidays: ["01/01/2014", "03/01/2014"]    # array items are either parseable date strings, or real Date objects
  extra_working_dates: [nil], # Makes the calendar to consider a weekend day as a working day.
)
```

### Load a calendar from a file

#### Calendar file definition

Defining a calendar as a Ruby object may not be convient, to load it from a YAML file follow and customise the example below. All keys are optional and will default to the following:

- If `working_days` is missing, then common default is used (mon-fri).
- If `holidays` is missing, "no holidays" assumed.
- If `extra_working_dates` is missing, then no changes in `working_days` will happen.

> Note: Elements of `holidays` and `extra_working_dates` may be eiter strings that `Date.parse()` can understand, or YYYY-MM-DD (which is considered as a Date by Ruby YAML itself).

#### Example

```yaml
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

#### Using the calendar

Ensure the calendar file is saved to a directory that will hold all your calendars, eg; `path/to/your/calendar/directory` then add this directory to your code before you call your calendar:

```ruby
Business::Calendar.load_paths = ["path/to/your/calendar/directory"]
```

Now you can load the calendar by calling the `load` class method on `Business::Calendar`. The
`load_cached` variant of this method caches the calendars by name after loading them, to avoid reading and parsing the config file multiple times.

```ruby
calendar = Business::Calendar.load("my_calendars")
# or
calendar = Business::Calendar.load_cached("my_calendars")
```

### Checking for business days

To check whether a given date is a business day (falls on one of the specified working days or working dates, and is not a holiday), use the `business_day?` method on `Business::Calendar`.

```ruby
calendar.business_day?(Date.parse("Monday, 9 June 2014"))
# => true
calendar.business_day?(Date.parse("Sunday, 8 June 2014"))
# => false
```

### Business day arithmetic

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

---


![I'm late for business](http://3.bp.blogspot.com/-aq4iOz2OZzs/Ty8xaQwMhtI/AAAAAAAABrM/-vn4tcRA9-4/s1600/daily-morning-awesomeness-243.jpeg)

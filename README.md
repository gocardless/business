# Business

Date calculations based on business calendars.


## Usage

```ruby
calendar = Business::Calendar.load('bacs')
date = Date.parse("2013-10-18")
calendar.add_business_days(date, 1)
# => 2013-10-21
```


## Why Business?

Another gem, business_time, also exists for this purpose. We previously used
business_time, but encountered several issues that prompted us to create
business.

Firstly, business_time works by monkey-patching `Date`, `Time`, and `FixNum`.
While this enables syntax like `Time.now + 1.business_day`, it means that all
configuration has to be global. GoCardless handles payments across multiple
geographies, so being able to work with multiple working-day calendars is
essential for us. Business provides a simple `Calendar` class, that is
initialized with a configuration that specifies which days of the week are
considered to be business days, and which dates are holidays.

Secondly, business_time supports calculations on times as well as dates. For
our purposes, date-based calculations are sufficient. Supporting time-based
calculations as well makes the code code significantly more complex. We chose
to avoid this extra complexity by sticking solely to date-based mathematics.



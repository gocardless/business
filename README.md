# BankTime

Date calculations based on bank calendars

## Usage

```ruby
calendar = BankTime::Calendar.load('bacs')
date = Date.parse("2013-10-18")
calendar.add_business_days(date, 1)
# => 2013-10-21
```


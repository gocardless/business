# Compatibility

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

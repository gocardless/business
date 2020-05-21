require "rutie"
require "business/calendar"

Rutie.new(:calendar_rust).init 'Init_calendar_rust', __dir__

class CalendarRust
  include Business::Calendar
end

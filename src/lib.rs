#[macro_use]
extern crate rutie;

#[macro_use]
extern crate lazy_static;

use chrono::{NaiveDate, Duration};

use rutie::{Class, Object, RString, Array, Boolean, VM, Integer, AnyObject, Hash, Symbol};

class!(Calendar);

methods!(
    Calendar,
    itself,

    fn calendar_rust_new(config: Hash) -> AnyObject {
        let config = config.unwrap_or(Hash::new());

        let working_days = config.at(&Symbol::new("working_days"))
            .try_convert_to::<Array>()
            .unwrap_or(Array::new())
            .into_iter()
            .map(|x| x.try_convert_to::<RString>())
            .map(|x| x.unwrap().to_string())
            .collect();

        let holidays: Vec<_> = config.at(&Symbol::new("holidays"))
            .try_convert_to::<Array>()
            .unwrap_or(Array::new())
            .into_iter()
            .map(|x| x.try_convert_to::<RString>())
            .map(|x| x.unwrap())
            .map(|x| NaiveDate::parse_from_str(x.to_str(), "%Y-%m-%d").unwrap())
            .collect();

        let extra_working_dates: Vec<_> = config.at(&Symbol::new("extra_working_dates"))
            .try_convert_to::<Array>()
            .unwrap_or(Array::new())
            .into_iter()
            .map(|x| x.try_convert_to::<RString>())
            .map(|x| x.unwrap())
            .map(|x| NaiveDate::parse_from_str(x.to_str(), "%Y-%m-%d").unwrap())
            .collect();

        Class::from_existing("Calendar").wrap_data(
            CalendarState::new(extra_working_dates, working_days, holidays),
            &*CALENDAR_WRAPPER
        )
    }

    // If no working days are provided in the calendar config, these are used.
    fn default_working_days() -> Array {
        let mut arr = Array::with_capacity(5);
        arr.push(RString::new_utf8("mon"));
        arr.push(RString::new_utf8("tue"));
        arr.push(RString::new_utf8("wed"));
        arr.push(RString::new_utf8("thu"));
        arr.push(RString::new_utf8("fri"));
        arr
    }

    fn is_business_day(date_string: RString) -> Boolean {
        let date_string = date_string.
            map_err(|e| VM::raise_ex(e) ).
            unwrap().
            to_string();

        let date = NaiveDate::parse_from_str(&date_string, "%Y-%m-%d").
            expect("Bad input");

        let result = itself.get_data(&*CALENDAR_WRAPPER).is_business_day(&date);

        Boolean::new(result)
    }

    fn roll_forward(date_string: RString) -> RString {
        let date_string = date_string.
            map_err(|e| VM::raise_ex(e) ).
            unwrap().
            to_string();

        let date = NaiveDate::parse_from_str(&date_string, "%Y-%m-%d").
            expect("Bad input");

        let result = itself.get_data(&*CALENDAR_WRAPPER).roll_forward(&date);
        RString::new_utf8(&result.format("%Y-%m-%d").to_string())
    }

    fn add_business_days(date_string: RString, delta: Integer) -> RString {
        let date_string = date_string.
            map_err(|e| VM::raise_ex(e) ).
            unwrap().
            to_string();

        let date = NaiveDate::parse_from_str(&date_string, "%Y-%m-%d").
            expect("Bad input");

        let delta = delta.
            map_err(|e| VM::raise_ex(e) ).
            unwrap().
            to_i32();

        let result = itself.get_data(&*CALENDAR_WRAPPER).add_business_days(&date, delta);
        RString::new_utf8(&result.format("%Y-%m-%d").to_string())
    }

    fn working_days() -> Array {
        let result = &itself.get_data(&*CALENDAR_WRAPPER).working_days;
        let mut arr = Array::with_capacity(result.len());
        for r in result {
            arr.push(RString::new_utf8(&r));
        }
        arr
    }

    fn holidays() -> Array {
        let result = &itself.get_data(&*CALENDAR_WRAPPER).holidays;
        let mut arr = Array::with_capacity(result.len());
        for r in result {
            arr.push(RString::new_utf8(&r.format("%Y-%m-%d").to_string()));
        }
        arr
    }

    fn extra_working_dates() -> Array {
        let result = &itself.get_data(&*CALENDAR_WRAPPER).extra_working_dates;
        let mut arr = Array::with_capacity(result.len());
        for r in result {
            arr.push(RString::new_utf8(&r.format("%Y-%m-%d").to_string()));
        }
        arr
    }
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Init_business() {
    Class::new("Calendar", None).define(|itself| {
        itself.def_self("new", calendar_rust_new);
        itself.def("default_working_days", default_working_days);
        itself.def("business_day?", is_business_day);
        itself.def("roll_forward", roll_forward);
        itself.def("add_business_days", add_business_days);
        itself.def("working_days", working_days);
        itself.def("holidays", holidays);
        itself.def("extra_working_dates", extra_working_dates);
    });
}

pub struct CalendarState {
    working_days: Vec<String>,
    holidays: Vec<NaiveDate>,
    extra_working_dates: Vec<NaiveDate>,
}

impl CalendarState {
    fn new(extra_working_dates: Vec<NaiveDate>, working_days: Vec<String>, holidays: Vec<NaiveDate>) -> Self {
        let working_days = if working_days.is_empty() {
            vec![
                "mon".to_string(),
                "tue".to_string(),
                "wed".to_string(),
                "thu".to_string(),
                "fri".to_string()
            ]
        } else {
            working_days
        };

        Self { working_days, holidays, extra_working_dates }
    }

    // Return true if the date given is a business day (typically that means a
    // non-weekend day) and not a holiday.
    fn is_business_day(&self, date: &NaiveDate) -> bool {
        if self.extra_working_dates.contains(&date) {
            return true
        }

        let day = date.format("%a").to_string().to_lowercase();
        if !self.working_days.contains(&day) {
            return false
        }

        !self.holidays.contains(&date)
    }

    // Roll forward to the next business day. If the date given is a business
    // day, that day will be returned. If the day given is a holiday or
    // non-working day, the next non-holiday working day will be returned.
    fn roll_forward(&self, date: &NaiveDate) -> NaiveDate {
        let mut result = date.clone();
        while !self.is_business_day(&result) {
            result += Duration::days(1);
        }
        result
    }

    // Add a number of business days to a date. If a non-business day is given,
    // counting will start from the next business day. So,
    //   monday + 1 = tuesday
    //   friday + 1 = monday
    //   sunday + 1 = tuesday
    fn add_business_days(&self, date: &NaiveDate, delta: i32) -> NaiveDate {
        let mut result = self.roll_forward(&date);

        for _ in 0..delta {
            loop {
                result += Duration::days(1);
                if self.is_business_day(&result) { break }
            }
        }

        result
    }
}

wrappable_struct!(CalendarState, CalendarWrapper, CALENDAR_WRAPPER);

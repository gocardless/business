#[macro_use]
extern crate rutie;

use chrono::{NaiveDate, Duration};

use rutie::{Class, Object, RString, Array, Boolean, VM, Integer};

class!(CalendarRust);

methods!(
    CalendarRust,
    _itself,

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

        Boolean::new(is_business_day_inner(&date))
    }

    fn roll_forward(date_string: RString) -> RString {
        let date_string = date_string.
            map_err(|e| VM::raise_ex(e) ).
            unwrap().
            to_string();

        let date = NaiveDate::parse_from_str(&date_string, "%Y-%m-%d").
            expect("Bad input");

        RString::new_utf8(&roll_forward_inner(&date).format("%Y-%m-%d").to_string())
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

        RString::new_utf8(&add_business_days_inner(&date, delta).format("%Y-%m-%d").to_string())
    }
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Init_calendar_rust() {
    Class::new("CalendarRust", None).define(|itself| {
        itself.def("default_working_days", default_working_days);
        itself.def("business_day?", is_business_day);
        itself.def("roll_forward", roll_forward);
        itself.def("add_business_days", add_business_days);
    });
}

fn working_days() -> Vec<String> {
    vec!["mon".to_string(), "tue".to_string(), "wed".to_string(), "thu".to_string(), "fri".to_string()]
}

fn holidays() -> Vec<NaiveDate> {
    vec![NaiveDate::from_ymd(2019, 12, 25)]
}

fn extra_working_dates() -> Vec<NaiveDate> {
    vec![]
}

// Return true if the date given is a business day (typically that means a
// non-weekend day) and not a holiday.
fn is_business_day_inner(date: &NaiveDate) -> bool {
    if extra_working_dates().contains(&date) {
        return true
    }

    let day = date.format("%a").to_string().to_lowercase();
    if !working_days().contains(&day) {
        return false
    }

    !holidays().contains(&date)
}

// Roll forward to the next business day. If the date given is a business
// day, that day will be returned. If the day given is a holiday or
// non-working day, the next non-holiday working day will be returned.
fn roll_forward_inner(date: &NaiveDate) -> NaiveDate {
    let mut result = date.clone();
    while !is_business_day_inner(&result) {
        result += Duration::days(1);
    }
    result
}

// Add a number of business days to a date. If a non-business day is given,
// counting will start from the next business day. So,
//   monday + 1 = tuesday
//   friday + 1 = monday
//   sunday + 1 = tuesday
fn add_business_days_inner(date: &NaiveDate, delta: i32) -> NaiveDate {
    let mut result = roll_forward_inner(&date);

    for _ in 0..delta {
        loop {
            result += Duration::days(1);
            if is_business_day_inner(&result) { break }
        }
    }

    result
}

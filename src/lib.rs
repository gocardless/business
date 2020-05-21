#[macro_use]
extern crate rutie;

use chrono::NaiveDate;

use rutie::{Class, Object, RString, Array, Boolean, VM};

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
            unwrap();

        let date = NaiveDate::parse_from_str(&date_string.to_string(), "%Y-%m-%d").
            expect("Bad input");
        let day = date.format("%a").to_string().to_lowercase();

        if !working_days().contains(&day) {
            return Boolean::new(false)
        }

        Boolean::new(!holidays().contains(&date))
    }
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Init_calendar_rust() {
    Class::new("CalendarRust", None).define(|itself| {
        itself.def("default_working_days", default_working_days);
        itself.def("business_day?", is_business_day);
    });
}

fn working_days() -> Vec<String> {
    vec!["mon", "tue", "wed", "thu", "fri"].iter().map(|x| x.to_string()).collect()
}

fn holidays() -> Vec<NaiveDate> {
    vec![NaiveDate::from_ymd(2019, 12, 25)]
}

#[macro_use]
extern crate rutie;

#[macro_use]
extern crate lazy_static;

use chrono::{NaiveDate, Duration};

use rutie::{Class, Object, RString, Array, Boolean, VM, Integer, AnyObject, Hash, Symbol};

class!(CalendarRust);

methods!(
    CalendarRust,
    itself,

    fn calendar_rust_new(config: Hash) -> AnyObject {
        let working_days = config.unwrap().at(&Symbol::new("working_days"))
            .try_convert_to::<Array>()
            .unwrap().into_iter()
            .map(|x| x.try_convert_to::<RString>())
            .map(|x| x.unwrap().to_string())
            .collect();

        println!("{:?}", &working_days);
        Class::from_existing("CalendarRust").wrap_data(Calendar::new(working_days), &*CALENDAR_WRAPPER)
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
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Init_calendar_rust() {
    Class::new("CalendarRust", None).define(|itself| {
        itself.def_self("new", calendar_rust_new);
        itself.def("default_working_days", default_working_days);
        itself.def("business_day?", is_business_day);
        itself.def("roll_forward", roll_forward);
        itself.def("add_business_days", add_business_days);
    });
}

pub struct Calendar {
    working_days: Vec<String>,
    holidays: Vec<NaiveDate>,
    extra_working_dates: Vec<NaiveDate>,
}

impl Calendar {
    fn new(working_days: Vec<String>) -> Self {
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

        Calendar {
            working_days,
            holidays: vec![NaiveDate::from_ymd(2019, 12, 25)],
            extra_working_dates: Vec::new(),
        }
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

wrappable_struct!(Calendar, CalendarWrapper, CALENDAR_WRAPPER);

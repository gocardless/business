#[macro_use]
extern crate rutie;

use rutie::{Module, Object, RString, Array};

module!(CalendarRust);

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
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Init_calendar_rust() {
    Module::new("CalendarRust").define(|itself| {
        itself.def("default_working_days", default_working_days);
    });
}

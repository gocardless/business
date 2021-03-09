## 2.2.1 - March 9, 2021

- Fix regression on `Calendar#new` #83 - thanks @ineu!

## 2.2.0 - March 4, 2021

- Add `Business::Calendar#name` - thanks @mattmcf!

## 2.1.0 - June 8, 2020

- Add seperate `working_day?` and `holiday?` methods to the calendar

## 2.0.0 - May 4, 2020

🚨 **BREAKING CHANGES** 🚨

For more on the breaking changes that have been introduced in v2.0.0 please [see the readme](README.md#v200-breaking-changes).

- Remove bundled calendars see [this pr](https://github.com/gocardless/business/pull/54) for more context. If you need to use any of the previously bundled calendars, [see here](https://github.com/gocardless/business/tree/b12c186ca6fd4ffdac85175742ff7e4d0a705ef4/lib/business/data)
- `Business::Calendar.load_paths=` is now required

## 1.18.0 - April 30, 2020

### Note we have dropped support for Ruby < 2.4.x

- Correct Danish public holidays

## 1.17.1 - November 19, 2019

- Change May Bank Holiday 2020 for UK (Bacs) - this was moved to the 8th.
- Add 2020 holidays for PAD.

## 1.17.0 - October 30, 2019

- Add holiday calendar for France (Target(SEPA) + French bank holidays)

## 1.16.1 - September 2, 2019

- Fix holiday calendar for ACH U.S.

## 1.16.0 - January 17, 2019

- Add holiday calendar for ACH U.S.

## 1.15.0 - October 24, 2018

- Add holiday calendar for PAD Canada

## 1.14.0 - July 18, 2018

- Add holiday calendar for BECS New Zealand

## 1.13.1 - June 22, 2018

- Fix June's 2018 bank holidays for Bankgirot

## 1.13.0 - April 17, 2018

- Add support for specifying `extra_working_dates` (special dates that are "working days",
  even though they are not one of the specified days, for example weekend dates
  that are considered to be working days)

## 1.12.0 - April 3, 2018

- Add Betalingservice & BECS calendars up until 2020

## 1.11.1 - December 20, 2017

- Add 2017-2018 BECS holiday definitions

## 1.11.0 - December 13, 2017

- Handle properly calendar initialization by Date objects (not strings),
  coming from both YAML config and initialize().


## 1.10.0 - September 20, 2017

- Add 2018-2019 Betalingsservice holiday definitions

## 1.9.0 - August 23, 2017

- Add 2017 Betalingsservice holiday definitions

## 1.8.0 - February 13, 2017

- Add 2018-2027 TARGET holiday defintions
- Add 2018-2027 Bankgirot holiday defintions

## 1.7.0 - January 18, 2017

- Add 2018-2027 BACS holiday defintions

## 1.6.0 - December 23, 2016

- Add 2017 BACS holiday definitions
- Add 2017 and 2018 TARGET holiday definitions

## 1.5.0 - June 2, 2015

- Add 2016 holiday definitions

## 1.4.0 - December 24, 2014

- Add support for custom calendar load paths
- Remove the 'sepa' calendar


## 1.3.0 - December 2, 2014

- Add `Calendar#previous_business_day`


## 1.2.0 - November 15, 2014

- Add TARGET calendar


## 1.1.0 - September 30, 2014

- Add 2015 holiday definitions


## 1.0.0 - June 11, 2014

- Initial public release

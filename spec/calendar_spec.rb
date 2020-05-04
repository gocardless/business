require "business/calendar"
require "time"

RSpec.configure do |config|
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.raise_errors_for_deprecations!
end

describe Business::Calendar do
  describe ".load" do
    before do
      fixture_path = File.join(File.dirname(__FILE__), 'fixtures', 'calendars')
      described_class.load_paths = [fixture_path]
    end

    context "when given a calendar from a custom directory" do
      subject { described_class.load("ecb") }

      after { described_class.load_paths = nil }

      it "loads the yaml file" do
        expect(YAML).to receive(:load_file) { |path|
          expect(path).to match(/ecb\.yml$/)
        }.and_return({})
        subject
      end

      it { is_expected.to be_a Business::Calendar }

      context "that also exists as a default calendar" do
        subject { Business::Calendar.load("bacs") }

        it "uses the custom calendar" do
          expect(subject.business_day?(Date.parse("25th December 2014"))).
            to eq(true)
        end
      end
    end

    context "when given a calendar that does not exist" do
      subject { Business::Calendar.load("invalid-calendar") }
      specify { expect { subject }.to raise_error(/No such calendar/) }
    end

    context "when given a calendar that has invalid keys" do
      subject { Business::Calendar.load("invalid-keys") }
      specify { expect { subject }.to raise_error("Only valid keys are: holidays, working_days, extra_working_dates") }
    end

    context "when given real business data" do
      let(:data_path) { File.join(File.dirname(__FILE__), '..', 'lib', 'business', 'data') }
      it "validates they are all loadable by the calendar" do
        Dir.glob("#{data_path}/*").each do |filename|
          calendar_name = File.basename(filename, ".yml")
          calendar = Business::Calendar.load(calendar_name)

          expect(calendar.working_days.length).to be >= 1
        end
      end
    end
  end

  describe "#set_working_days" do
    let(:calendar) { Business::Calendar.new({}) }
    let(:working_days) { [] }
    subject { calendar.set_working_days(working_days) }

    context "when given valid working days" do
      let(:working_days) { %w( mon fri ) }
      before { subject }

      it "assigns them" do
        expect(calendar.working_days).to eq(working_days)
      end

      context "that are unnormalised" do
        let(:working_days) { %w( Monday Friday ) }
        it "normalises them" do
          expect(calendar.working_days).to eq(%w( mon fri ))
        end
      end
    end

    context "when given an invalid business day" do
      let(:working_days) { %w( Notaday ) }
      specify { expect { subject }.to raise_error(/Invalid day/) }
    end

    context "when given nil" do
      let(:working_days) { nil }
      it "uses the default business days" do
        expect(calendar.working_days).to eq(calendar.default_working_days)
      end
    end
  end

  describe "#set_holidays" do
    let(:calendar) { Business::Calendar.new({}) }
    let(:holidays) { [] }
    before { calendar.set_holidays(holidays) }
    subject { calendar.holidays }

    context "when given valid business days" do
      let(:holidays) { ["1st Jan, 2013"] }

      it { is_expected.not_to be_empty }

      it "converts them to Date objects" do
        subject.each { |h| expect(h).to be_a Date }
      end
    end

    context "when given nil" do
      let(:holidays) { nil }
      it { is_expected.to be_empty }
    end
  end

  describe "#set_extra_working_dates" do
    let(:calendar) { Business::Calendar.new({}) }
    let(:extra_working_dates) { [] }
    before { calendar.set_extra_working_dates(extra_working_dates) }
    subject { calendar.extra_working_dates }

    context "when given valid business days" do
      let(:extra_working_dates) { ["1st Jan, 2013"] }

      it { is_expected.not_to be_empty }

      it "converts them to Date objects" do
        subject.each { |h| expect(h).to be_a Date }
      end
    end

    context "when given nil" do
      let(:holidays) { nil }
      it { is_expected.to be_empty }
    end
  end

  context "when holiday is also a working date" do
    subject do
      Business::Calendar.new(holidays: ["2018-01-06"],
                             extra_working_dates: ["2018-01-06"])
    end

    it do
      expect { subject }.to raise_error(ArgumentError)
        .with_message('Holidays cannot be extra working dates')
    end
  end

  context "when working date on working day" do
    subject do
      Business::Calendar.new(working_days: ["mon"],
                             extra_working_dates: ["Monday 26th Mar, 2018"])
    end

    it do
      expect { subject }.to raise_error(ArgumentError)
        .with_message('Extra working dates cannot be on working days')
    end
  end

  # A set of examples that are supposed to work when given Date and Time
  # objects. The implementation slightly differs, so i's worth running the
  # tests for both Date *and* Time.
  shared_examples "common" do
    describe "#business_day?" do
      let(:calendar) do
        Business::Calendar.new(holidays: ["9am, Tuesday 1st Jan, 2013"],
                               extra_working_dates: ["9am, Sunday 6th Jan, 2013"])
      end
      subject { calendar.business_day?(day) }

      context "when given a business day" do
        let(:day) { date_class.parse("9am, Wednesday 2nd Jan, 2013") }
        it { is_expected.to be_truthy }
      end

      context "when given a non-business day" do
        let(:day) { date_class.parse("9am, Saturday 5th Jan, 2013") }
        it { is_expected.to be_falsey }
      end

      context "when given a business day that is a holiday" do
        let(:day) { date_class.parse("9am, Tuesday 1st Jan, 2013") }
        it { is_expected.to be_falsey }
      end

      context "when given a non-business day that is a working date" do
        let(:day) { date_class.parse("9am, Sunday 6th Jan, 2013") }
        it { is_expected.to be_truthy }
      end
    end

    describe "#roll_forward" do
      let(:calendar) do
        Business::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.roll_forward(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { is_expected.to eq(date) }
      end

      context "given a non-business day" do
        context "with a business day following it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { is_expected.to eq(date + day_interval) }
        end

        context "followed by another non-business day" do
          let(:date) { date_class.parse("Saturday 5th Jan, 2013") }
          it { is_expected.to eq(date + 2 * day_interval) }
        end
      end
    end

    describe "#roll_backward" do
      let(:calendar) do
        Business::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.roll_backward(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { is_expected.to eq(date) }
      end

      context "given a non-business day" do
        context "with a business day preceeding it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { is_expected.to eq(date - day_interval) }
        end

        context "preceeded by another non-business day" do
          let(:date) { date_class.parse("Sunday 6th Jan, 2013") }
          it { is_expected.to eq(date - 2 * day_interval) }
        end
      end
    end

    describe "#next_business_day" do
      let(:calendar) do
        Business::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.next_business_day(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { is_expected.to eq(date + day_interval) }
      end

      context "given a non-business day" do
        context "with a business day following it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { is_expected.to eq(date + day_interval) }
        end

        context "followed by another non-business day" do
          let(:date) { date_class.parse("Saturday 5th Jan, 2013") }
          it { is_expected.to eq(date + 2 * day_interval) }
        end
      end
    end

    describe "#previous_business_day" do
      let(:calendar) do
        Business::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.previous_business_day(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Thursday 3nd Jan, 2013") }
        it { is_expected.to eq(date - day_interval) }
      end

      context "given a non-business day" do
        context "with a business day before it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { is_expected.to eq(date - day_interval) }
        end

        context "preceeded by another non-business day" do
          let(:date) { date_class.parse("Sunday 6th Jan, 2013") }
          it { is_expected.to eq(date - 2 * day_interval) }
        end
      end
    end

    describe "#add_business_days" do
      let(:extra_working_dates) { [] }
      let(:calendar) do
        Business::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"],
                               extra_working_dates: extra_working_dates)
      end
      let(:delta) { 2 }
      subject { calendar.add_business_days(date, delta) }

      context "given a business day" do
        context "and a period that includes only business days" do
          let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
          it { is_expected.to eq(date + delta * day_interval) }
        end

        context "and a period that includes a weekend" do
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { is_expected.to eq(date + (delta + 2) * day_interval) }
        end

        context "and a period that includes a working date weekend" do
          let(:extra_working_dates) { ["Sunday 6th Jan, 2013"] }
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { is_expected.to eq(date + (delta + 1) * day_interval) }
        end

        context "and a period that includes a holiday day" do
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { is_expected.to eq(date + (delta + 1) * day_interval) }
        end
      end

      context "given a non-business day" do
        let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
        it { is_expected.to eq(date + (delta + 1) * day_interval) }
      end
    end

    describe "#subtract_business_days" do
      let(:extra_working_dates) { [] }
      let(:calendar) do
        Business::Calendar.new(holidays: ["Thursday 3rd Jan, 2013"],
                               extra_working_dates: extra_working_dates)
      end
      let(:delta) { 2 }
      subject { calendar.subtract_business_days(date, delta) }

      context "given a business day" do
        context "and a period that includes only business days" do
          let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
          it { is_expected.to eq(date - delta * day_interval) }
        end

        context "and a period that includes a weekend" do
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { is_expected.to eq(date - (delta + 2) * day_interval) }
        end

        context "and a period that includes a working date weekend" do
          let(:extra_working_dates) { ["Saturday 29th Dec, 2012"] }
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { is_expected.to eq(date - (delta + 1) * day_interval) }
        end

        context "and a period that includes a holiday day" do
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { is_expected.to eq(date - (delta + 1) * day_interval) }
        end
      end

      context "given a non-business day" do
        let(:date) { date_class.parse("Thursday 3rd Jan, 2013") }
        it { is_expected.to eq(date - (delta + 1) * day_interval) }
      end
    end

    describe "#business_days_between" do
      let(:holidays) do
        ["Wed 27/5/2014", "Thu 12/6/2014", "Wed 18/6/2014", "Fri 20/6/2014",
         "Sun 22/6/2014", "Fri 27/6/2014", "Thu 3/7/2014"]
      end
      let(:extra_working_dates) do
        ["Sun 1/6/2014", "Sat 28/6/2014", "Sat 5/7/2014"]
      end
      let(:calendar) do
        Business::Calendar.new(holidays: holidays, extra_working_dates: extra_working_dates)
      end
      subject do
        calendar.business_days_between(date_class.parse(date_1),
                                       date_class.parse(date_2))
      end

      context "starting on a business day" do
        let(:date_1) { "Mon 2/6/2014" }

        context "ending on a business day" do
          context "including only business days" do
            let(:date_2) { "Thu 5/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including only business days & weekend days" do
            let(:date_2) { "Mon 9/6/2014" }
            it { is_expected.to eq(5) }
          end

          context "including only business days, weekend days & working date" do
            let(:date_1) { "Thu 29/5/2014" }
            let(:date_2) { "The 3/6/2014" }
            it { is_expected.to eql(4) }
          end

          context "including only business days & holidays" do
            let(:date_1) { "Mon 9/6/2014" }
            let(:date_2) { "Fri 13/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Fri 13/6/2014" }
            it { is_expected.to eq(8) }
          end

          context "including business, weekend, hoilday days & working date" do
            let(:date_1) { "Thu 26/6/2014" }
            let(:date_2) { "The 1/7/2014" }
            it { is_expected.to eql(3) }
          end
        end

        context "ending on a weekend day" do
          context "including only business days & weekend days" do
            let(:date_2) { "Sun 8/6/2014" }
            it { is_expected.to eq(5) }
          end

          context "including business & weekend days & working date" do
            let(:date_1) { "Thu 29/5/2014" }
            let(:date_2) { "Sun 3/6/2014" }
            it { is_expected.to eq(4) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Sat 14/6/2014" }
            it { is_expected.to eq(9) }
          end

          context "including business, weekend & holiday days & working date" do
            let(:date_1) { "Thu 26/6/2014" }
            let(:date_2) { "Tue 2/7/2014" }
            it { is_expected.to eq(4) }
          end
        end

        context "ending on a holiday" do
          context "including only business days & holidays" do
            let(:date_1) { "Mon 9/6/2014" }
            let(:date_2) { "Thu 12/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Thu 12/6/2014" }
            it { is_expected.to eq(8) }
          end

          context 'including business, weekend, holiday days & business date' do
            let(:date_1) { "Wed 28/5/2014" }
            let(:date_2) { "Thu 12/6/2014" }
            it { is_expected.to eq(11) }
          end
        end

        context "ending on a working date" do
          let(:date_1) { "Fri 4/7/2014" }

          context "including only business days & working date" do
            let(:date_2) { "Sat 5/7/2014" }
            it { is_expected.to eq(1) }
          end

          context "including business, weekend days & working date" do
            let(:date_2) { "Tue 8/7/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, holidays & working date" do
            let(:date_1) { "Wed 25/6/2014" }
            let(:date_2) { "Tue 8/7/2014" }
            it { is_expected.to eq(8) }
          end
        end
      end

      context "starting on a weekend" do
        let(:date_1) { "Sat 7/6/2014" }

        context "ending on a business day" do

          context "including only business days & weekend days" do
            let(:date_2) { "Mon 9/6/2014" }
            it { is_expected.to eq(0) }
          end

          context "including business, weekend days & working date" do
            let(:date_1) { "Sat 31/5/2014" }
            let(:date_2) { "Tue 3/6/2014" }
            it { is_expected.to eq(2) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Fri 13/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend, holilday days & working date" do
            let(:date_1) { "Sat 31/5/2014" }
            let(:date_2) { "Fri 13/6/2014" }
            it { is_expected.to eq(8) }
          end
        end

        context "ending on a weekend day" do
          context "including only business days & weekend days" do
            let(:date_2) { "Sun 8/6/2014" }
            it { is_expected.to eq(0) }
          end

          context "including business, weekend days & working date" do
            let(:date_1) { "Sat 31/5/2014" }
            let(:date_2) { "Sun 8/6/2014" }
            it { is_expected.to eql(5) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Sat 14/6/2014" }
            it { is_expected.to eq(4) }
          end

          context "including business, weekend, holiday days & working date" do
            let(:date_1) { "Sat 31/5/2014" }
            let(:date_2) { "Sun 14/6/2014" }
            it { is_expected.to eql(9) }
          end
        end

        context "ending on a holiday" do
          context "including business, weekend days, and holidays" do
            let(:date_2) { "Thu 12/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days & working date" do
            let(:date_1) { "Sat 31/5/2014" }
            let(:date_2) { "Thu 12/6/2014" }
            it { is_expected.to eq(8) }
          end
        end

        context "ending on a working date" do
          let(:date_1) { "Sat 31/5/2014" }

          context "including only weekend days & working date" do
            let(:date_2) { "Sat 2/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including business, weekend days & working date" do
            let(:date_2) { "Tue 4/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, holidays & working date" do
            let(:date_2) { "Tue 13/6/2014" }
            it { is_expected.to eq(8) }
          end
        end
      end

      context "starting on a holiday" do
        let(:date_1) { "Thu 12/6/2014" }

        context "ending on a business day" do

          context "including only business days & holidays" do
            let(:date_2) { "Fri 13/6/2014" }
            it { is_expected.to eq(0) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Thu 19/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, holidays & working date" do
            let(:date_1) { "Fri 27/6/2014" }
            let(:date_2) { "Tue 1/7/2014" }
            it { is_expected.to eq(2) }
          end
        end

        context "ending on a weekend day" do
          context "including business, weekend days, and holidays" do
            let(:date_2) { "Sun 15/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including business, weekend days, holidays & working date" do
            let(:date_1) { "Fri 27/6/2014" }
            let(:date_2) { "Sun 29/6/2014" }
            it { is_expected.to eq(1) }
          end
        end

        context "ending on a holiday" do
          context "including only business days & holidays" do
            let(:date_1) { "Wed 18/6/2014" }
            let(:date_2) { "Fri 20/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { "Wed 18/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including business/weekend days, holidays & working date" do
            let(:date_1) { "27/5/2014" }
            let(:date_2) { "Thu 12/6/2014" }
            it { is_expected.to eq(11) }
          end
        end

        context "ending on a working date" do
          let(:date_1) { "Sat 27/6/2014" }

          context "including only holiday & working date" do
            let(:date_2) { "Sat 29/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including holiday, weekend days & working date" do
            let(:date_2) { "Tue 30/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including business, weekend days, holidays & working date" do
            let(:date_2) { "Tue 2/7/2014" }
            it { is_expected.to eq(3) }
          end
        end
      end

      context 'starting on a working date' do
        let(:date_1) { "Sun 1/6/2014" }

        context "ending on a working day" do
          context "including only working date & working day" do
            let(:date_2) { "Wed 4/6/2014" }
            it { is_expected.to eq(3) }
          end

          context "including working date, working & weekend days" do
            let(:date_2) { "Tue 10/6/2014" }
            it { is_expected.to eq(6) }
          end

          context "including working date, working & weekend days & holiday" do
            let(:date_2) { "Tue 13/6/2014" }
            it { is_expected.to eq(8) }
          end
        end

        context "ending on a weekend day" do
          let(:date_1) { "Sat 28/6/2014" }

          context "including only working date & weekend day" do
            let(:date_2) { "Sun 29/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including working date, weekend & working days" do
            let(:date_1) { "Sat 5/7/2014" }
            let(:date_2) { "Wed 9/7/2014" }
            it { is_expected.to eq(3) }
          end

          context "including working date, weekend & working days & holiday" do
            let(:date_2) { "Fri 4/7/2014" }
            it { is_expected.to eq(4) }
          end
        end

        context "ending on a holiday" do
          let(:date_1) { "Sat 28/6/2014" }

          context "including only working date & holiday" do
            let(:holidays) { ["Mon 2/6/2014"] }
            let(:date_1) { "Sun 1/6/2014" }
            let(:date_2) { "Mon 2/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including working date, holiday & weekend day" do
            let(:holidays) { ["Mon 30/6/2014"] }
            let(:date_2) { "Mon 30/6/2014" }
            it { is_expected.to eq(1) }
          end

          context "including working date, holiday, weekend & working days" do
            let(:date_2) { "Thu 3/7/2014" }
            it { is_expected.to eq(4) }
          end
        end

        context "ending on a working date" do
          context "including working dates, weekend & working days" do
            let(:date_1) { "Sat 28/6/2014" }
            let(:date_2) { "Sat 5/7/2014" }
            it { is_expected.to eq(4) }
          end
        end
      end

      context "if a calendar has a holiday on a non-working (weekend) day" do
        context "for a range less than a week long" do
          let(:date_1) { "Thu 19/6/2014" }
          let(:date_2) { "Tue 24/6/2014" }
          it { is_expected.to eq(2) }
        end
        context "for a range more than a week long" do
          let(:date_1) { "Mon 16/6/2014" }
          let(:date_2) { "Tue 24/6/2014" }
          it { is_expected.to eq(4) }
        end
      end
    end
  end

  context "(using Date objects)" do
    let(:date_class) { Date }
    let(:day_interval) { 1 }

    it_behaves_like "common"
  end

  context "(using Time objects)" do
    let(:date_class) { Time }
    let(:day_interval) { 3600 * 24 }

    it_behaves_like "common"
  end

  context "(using DateTime objects)" do
    let(:date_class) { DateTime }
    let(:day_interval) { 1 }

    it_behaves_like "common"
  end
end

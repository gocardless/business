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
      Business::Calendar.additional_load_paths = [fixture_path]
    end

    context "when given a valid calendar" do
      subject { Business::Calendar.load("weekdays") }

      it "loads the yaml file" do
        expect(YAML).to receive(:load_file) { |path|
          expect(path).to match(/weekdays\.yml$/)
        }.and_return({})
        subject
      end

      it { is_expected.to be_a Business::Calendar }
    end

    context "when given a calendar from a custom directory" do
      after { Business::Calendar.additional_load_paths = nil }
      subject { Business::Calendar.load("ecb") }

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
      specify { expect { subject }.to raise_error("Only valid keys are: holidays, working_days, working_dates") }
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

  describe "#set_working_dates" do
    let(:calendar) { Business::Calendar.new({}) }
    let(:working_dates) { [] }
    before { calendar.set_working_dates(working_dates) }
    subject { calendar.working_dates }

    context "when given valid business days" do
      let(:working_dates) { ["1st Jan, 2013"] }

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

  # A set of examples that are supposed to work when given Date and Time
  # objects. The implementation slightly differs, so i's worth running the
  # tests for both Date *and* Time.
  shared_examples "common" do
    describe "#business_day?" do
      let(:calendar) do
        Business::Calendar.new(holidays: ["9am, Tuesday 1st Jan, 2013"])
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
      let(:calendar) do
        Business::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
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
      let(:calendar) do
        Business::Calendar.new(holidays: ["Thursday 3rd Jan, 2013"])
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
        ["Thu 12/6/2014", "Wed 18/6/2014", "Fri 20/6/2014", "Sun 22/6/2014"]
      end
      let(:calendar) { Business::Calendar.new(holidays: holidays) }
      subject { calendar.business_days_between(date_1, date_2) }


      context "starting on a business day" do
        let(:date_1) { date_class.parse("Mon 2/6/2014") }

        context "ending on a business day" do
          context "including only business days" do
            let(:date_2) { date_class.parse("Thu 5/6/2014") }
            it { is_expected.to eq(3) }
          end

          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Mon 9/6/2014") }
            it { is_expected.to eq(5) }
          end

          context "including only business days & holidays" do
            let(:date_1) { date_class.parse("Mon 9/6/2014") }
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { is_expected.to eq(8) }
          end
        end

        context "ending on a weekend day" do
          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Sun 8/6/2014") }
            it { is_expected.to eq(5) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Sat 14/6/2014") }
            it { is_expected.to eq(9) }
          end
        end

        context "ending on a holiday" do
          context "including only business days & holidays" do
            let(:date_1) { date_class.parse("Mon 9/6/2014") }
            let(:date_2) { date_class.parse("Thu 12/6/2014") }
            it { is_expected.to eq(3) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Thu 12/6/2014") }
            it { is_expected.to eq(8) }
          end
        end
      end

      context "starting on a weekend" do
        let(:date_1) { date_class.parse("Sat 7/6/2014") }

        context "ending on a business day" do

          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Mon 9/6/2014") }
            it { is_expected.to eq(0) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { is_expected.to eq(3) }
          end
        end

        context "ending on a weekend day" do
          context "including only business days & weekend days" do
            let(:date_2) { date_class.parse("Sun 8/6/2014") }
            it { is_expected.to eq(0) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Sat 14/6/2014") }
            it { is_expected.to eq(4) }
          end
        end

        context "ending on a holiday" do
          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Thu 12/6/2014") }
            it { is_expected.to eq(3) }
          end
        end
      end

      context "starting on a holiday" do
        let(:date_1) { date_class.parse("Thu 12/6/2014") }

        context "ending on a business day" do

          context "including only business days & holidays" do
            let(:date_2) { date_class.parse("Fri 13/6/2014") }
            it { is_expected.to eq(0) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Thu 19/6/2014") }
            it { is_expected.to eq(3) }
          end
        end

        context "ending on a weekend day" do
          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Sun 15/6/2014") }
            it { is_expected.to eq(1) }
          end
        end

        context "ending on a holiday" do
          context "including only business days & holidays" do
            let(:date_1) { date_class.parse("Wed 18/6/2014") }
            let(:date_2) { date_class.parse("Fri 20/6/2014") }
            it { is_expected.to eq(1) }
          end

          context "including business, weekend days, and holidays" do
            let(:date_2) { date_class.parse("Wed 18/6/2014") }
            it { is_expected.to eq(3) }
          end
        end
      end

      context "if a calendar has a holiday on a non-working (weekend) day" do
        context "for a range less than a week long" do
          let(:date_1) { date_class.parse("Thu 19/6/2014") }
          let(:date_2) { date_class.parse("Tue 24/6/2014") }
          it { is_expected.to eq(2) }
        end
        context "for a range more than a week long" do
          let(:date_1) { date_class.parse("Mon 16/6/2014") }
          let(:date_2) { date_class.parse("Tue 24/6/2014") }
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


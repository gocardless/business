require "bank_time/calendar"
require "time"

describe BankTime::Calendar do
  describe ".load" do
    context "when given a valid calendar" do
      subject { BankTime::Calendar.load("weekdays") }

      it "loads the yaml file" do
        YAML.should_receive(:load_file) do |path|
          path.should match(/weekdays\.yml$/)
        end.and_return({})
        subject
      end

      it { should be_a BankTime::Calendar }
    end

    context "when given an invalid calendar" do
      subject { BankTime::Calendar.load("invalid-calendar") }
      specify { ->{ subject }.should raise_error }
    end
  end

  describe "#set_business_days" do
    let(:calendar) { BankTime::Calendar.new({}) }
    let(:business_days) { [] }
    subject { calendar.set_business_days(business_days) }

    context "when given valid business days" do
      let(:business_days) { %w( mon fri ) }
      before { subject }

      it "assigns them" do
        calendar.business_days.should == business_days
      end

      context "that are unnormalised" do
        let(:business_days) { %w( Monday Friday ) }
        it "normalises them" do
          calendar.business_days.should == %w( mon fri )
        end
      end
    end

    context "when given an invalid business day" do
      let(:business_days) { %w( Notaday ) }
      specify { ->{ subject }.should raise_exception }
    end

    context "when given nil" do
      let(:business_days) { nil }
      it "uses the default business days" do
        calendar.business_days.should == calendar.default_business_days
      end
    end
  end

  describe "#set_holidays" do
    let(:calendar) { BankTime::Calendar.new({}) }
    let(:holidays) { [] }
    before { calendar.set_holidays(holidays) }
    subject { calendar.holidays }

    context "when given valid business days" do
      let(:holidays) { ["1st Jan, 2013"] }

      it { should_not be_empty }

      it "converts them to Date objects" do
        subject.each { |h| h.should be_a Date }
      end
    end

    context "when given nil" do
      let(:holidays) { nil }
      it { should be_empty }
    end
  end

  # A set of examples that are supposed to work when given Date and Time
  # objects. The implementation slightly differs, so i's worth running the
  # tests for both Date *and* Time.
  shared_examples "common" do
    describe "#business_day?" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["9am, Tuesday 1st Jan, 2013"])
      end
      subject { calendar.business_day?(day) }

      context "when given a business day" do
        let(:day) { date_class.parse("9am, Wednesday 2nd Jan, 2013") }
        it { should be_true }
      end

      context "when given a non-business day" do
        let(:day) { date_class.parse("9am, Saturday 5th Jan, 2013") }
        it { should be_false }
      end

      context "when given a business day that is a holiday" do
        let(:day) { date_class.parse("9am, Tuesday 1st Jan, 2013") }
        it { should be_false }
      end
    end

    describe "#roll_forward" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.roll_forward(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { should == date }
      end

      context "given a non-business day" do
        context "with a business day following it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { should == date + day_interval }
        end

        context "followed by another non-business day" do
          let(:date) { date_class.parse("Saturday 5th Jan, 2013") }
          it { should == date + 2 * day_interval }
        end
      end
    end

    describe "#roll_backward" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.roll_backward(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { should == date }
      end

      context "given a non-business day" do
        context "with a business day preceeding it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { should == date - day_interval }
        end

        context "preceeded by another non-business day" do
          let(:date) { date_class.parse("Sunday 6th Jan, 2013") }
          it { should == date - 2 * day_interval }
        end
      end
    end

    describe "#next_business_day" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      subject { calendar.next_business_day(date) }

      context "given a business day" do
        let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
        it { should == date + day_interval }
      end

      context "given a non-business day" do
        context "with a business day following it" do
          let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
          it { should == date + day_interval }
        end

        context "followed by another non-business day" do
          let(:date) { date_class.parse("Saturday 5th Jan, 2013") }
          it { should == date + 2 * day_interval }
        end
      end
    end

    describe "#add_business_days" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Tuesday 1st Jan, 2013"])
      end
      let(:delta) { 2 }
      subject { calendar.add_business_days(date, delta) }

      context "given a business day" do
        context "and a period that includes only business days" do
          let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
          it { should == date + delta * day_interval }
        end

        context "and a period that includes a weekend" do
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { should == date + (delta + 2) * day_interval }
        end

        context "and a period that includes a holiday day" do
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { should == date + (delta + 1) * day_interval }
        end
      end

      context "given a non-business day" do
        let(:date) { date_class.parse("Tuesday 1st Jan, 2013") }
        it { should == date + (delta + 1) * day_interval }
      end
    end

    describe "#subtract_business_days" do
      let(:calendar) do
        BankTime::Calendar.new(holidays: ["Thursday 3rd Jan, 2013"])
      end
      let(:delta) { 2 }
      subject { calendar.subtract_business_days(date, delta) }

      context "given a business day" do
        context "and a period that includes only business days" do
          let(:date) { date_class.parse("Wednesday 2nd Jan, 2013") }
          it { should == date - delta * day_interval }
        end

        context "and a period that includes a weekend" do
          let(:date) { date_class.parse("Monday 31st Dec, 2012") }
          it { should == date - (delta + 2) * day_interval }
        end

        context "and a period that includes a holiday day" do
          let(:date) { date_class.parse("Friday 4th Jan, 2013") }
          it { should == date - (delta + 1) * day_interval }
        end
      end

      context "given a non-business day" do
        let(:date) { date_class.parse("Thursday 3rd Jan, 2013") }
        it { should == date - (delta + 1) * day_interval }
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


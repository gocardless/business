require 'yaml'

module BankTime
  class Calendar
    def self.load(calendar)
      path = File.join(File.dirname(__FILE__), 'data', "#{calendar}.yml")
      raise "No such calendar '#{calendar}'" unless File.exists?(path)
      yaml = YAML.load_file(path)
      self.new(holidays: yaml['holidays'], business_days: yaml['business_days'])
    end

    @lock = Mutex.new
    def self.load_cached(calendar)
       @lock.synchronize do
          @cache ||= { }
          unless @cache.include?(calendar)
            @cache[calendar] = self.load(calendar)
          end
          @cache[calendar]
      end
    end

    DAY_NAMES = %( mon tue wed thu fri sat sun )

    attr_reader :business_days, :holidays

    def initialize(config)
      set_business_days(config[:business_days])
      set_holidays(config[:holidays])
    end

    # Return true if the date given is a business day (typically that means a
    # non-weekend day) and not a holiday.
    def business_day?(date)
      date = date.to_date
      return false unless business_days.include?(date.strftime('%a').downcase)
      return false if holidays.include?(date)
      true
    end

    # Roll forward to the next business day. If the date given is a business
    # day, that day will be returned. If the day given is a holiday or
    # non-working day, the next non-holiday working day will be returned.
    def roll_forward(date)
      interval = date.is_a?(Date) ? 1 : 3600 * 24
      date += interval until business_day?(date)
      date
    end

    # Roll backward to the previous business day. If the date given is a
    # business day, that day will be returned. If the day given is a holiday or
    # non-working day, the previous non-holiday working day will be returned.
    def roll_backward(date)
      date -= day_interval_for(date) until business_day?(date)
      date
    end

    # Roll forward to the next business day regardless of whether the given
    # date is a business day or not.
    def next_business_day(date)
      begin
        date += day_interval_for(date)
      end until business_day?(date)
      date
    end

    # Add a number of business days to a date. If a non-business day is given,
    # counting will start from the next business day. So,
    #   monday + 1 = tuesday
    #   friday + 1 = monday
    #   sunday + 1 = tuesday
    def add_business_days(date, delta)
      date = roll_forward(date)
      delta.times do
        begin
          date += day_interval_for(date)
        end until business_day?(date)
      end
      date
    end

    # Subtract a number of business days to a date. If a non-business day is
    # given, counting will start from the previous business day. So,
    #   friday - 1 = thursday
    #   monday - 1 = friday
    #   sunday - 1 = thursday
    def subtract_business_days(date, delta)
      date = roll_backward(date)
      delta.times do
        begin
          date -= day_interval_for(date)
        end until business_day?(date)
      end
      date
    end

    # Count the number of business days between two dates.
    # This method counts from start of date1 to end of date2. So,
    # business_days_between(mon, weds) = 3 (assuming new holidays)
    def business_days_between(date1, date2)
      date1 = date1.to_date
      date2 = date2.to_date
      (date1..date2).select { |a| business_day?(a) }.count
    end

    def day_interval_for(date)
      date.is_a?(Date) ? 1 : 3600 * 24
    end

    # Internal method for assigning business days from a calendar config.
    def set_business_days(business_days)
      @business_days = (business_days || default_business_days).map do |day|
        day.downcase.strip[0..2].tap do |normalised_day|
          raise "Invalid day #{day}" unless DAY_NAMES.include?(normalised_day)
        end
      end
    end

    # Internal method for assigning holidays from a calendar config.
    def set_holidays(holidays)
      @holidays = (holidays || []).map { |holiday| Date.parse(holiday) }
    end

    # If no business days are provided in the calendar config, these are used.
    def default_business_days
      %w( mon tue wed thu fri )
    end
  end
end


require 'yaml'

module Business
  class Calendar
    class << self
      attr_accessor :load_paths
    end

    def self.calendar_directories
      @load_paths
    end
    private_class_method :calendar_directories

    def self.load(calendar_name)
      data = calendar_directories.detect do |path|
        if path.is_a?(Hash)
          break path[calendar_name] if path[calendar_name]
        else
          next unless File.exists?(File.join(path, "#{calendar_name}.yml"))

          break YAML.load_file(File.join(path, "#{calendar_name}.yml"))
        end
      end

      raise "No such calendar '#{calendar_name}'" unless data

      valid_keys = %w(holidays working_days extra_working_dates)

      unless (data.keys - valid_keys).empty?
        raise "Only valid keys are: #{valid_keys.join(', ')}"
      end

      self.new(
        holidays: data['holidays'],
        working_days: data['working_days'],
        extra_working_dates: data['extra_working_dates'],
      )
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

    attr_reader :holidays, :working_days, :extra_working_dates

    def initialize(config)
      set_extra_working_dates(config[:extra_working_dates])
      set_working_days(config[:working_days])
      set_holidays(config[:holidays])
    end

    # Return true if the date given is a business day (typically that means a
    # non-weekend day) and not a holiday.
    def business_day?(date)
      date = date.to_date
      return true if extra_working_dates.include?(date)
      return false unless working_days.include?(date.strftime('%a').downcase)
      return false if holidays.include?(date)
      true
    end

    # Roll forward to the next business day. If the date given is a business
    # day, that day will be returned. If the day given is a holiday or
    # non-working day, the next non-holiday working day will be returned.
    def roll_forward(date)
      date += day_interval_for(date) until business_day?(date)
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

    # Roll backward to the previous business day regardless of whether the given
    # date is a business day or not.
    def previous_business_day(date)
      begin
        date -= day_interval_for(date)
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
    # This method counts from start of date1 to start of date2. So,
    # business_days_between(mon, weds) = 2 (assuming no holidays)
    def business_days_between(date1, date2)
      date1, date2 = date1.to_date, date2.to_date

      # To optimise this method we split the range into full weeks and a
      # remaining period.
      #
      # We then calculate business days in the full weeks period by
      # multiplying number of weeks by number of working days in a week and
      # removing holidays one by one.

      # For the remaining period, we just loop through each day and check
      # whether it is a business day.

      # Calculate number of full weeks and remaining days
      num_full_weeks, remaining_days = (date2 - date1).to_i.divmod(7)

      # First estimate for full week range based on # biz days in a week
      num_biz_days = num_full_weeks * working_days.length

      full_weeks_range = (date1...(date2 - remaining_days))
      num_biz_days -= holidays.count do |holiday|
        in_range = full_weeks_range.cover?(holiday)
        # Only pick a holiday if its on a working day (e.g., not a weekend)
        on_biz_day = working_days.include?(holiday.strftime('%a').downcase)
        in_range && on_biz_day
      end

      remaining_range = (date2-remaining_days...date2)
      # Loop through each day in remaining_range and count if a business day
      num_biz_days + remaining_range.count { |a| business_day?(a) }
    end

    def day_interval_for(date)
      date.is_a?(Date) ? 1 : 3600 * 24
    end

    # Internal method for assigning working days from a calendar config.
    def set_working_days(working_days)
      @working_days = (working_days || default_working_days).map do |day|
        day.downcase.strip[0..2].tap do |normalised_day|
          raise "Invalid day #{day}" unless DAY_NAMES.include?(normalised_day)
        end
      end
      extra_working_dates_names = @extra_working_dates.map { |d| d.strftime("%a").downcase }
      return if (extra_working_dates_names & @working_days).none?
      raise ArgumentError, 'Extra working dates cannot be on working days'
    end

    def parse_dates(dates)
      (dates || []).map { |date| date.is_a?(Date) ? date : Date.parse(date) }
    end

    # Internal method for assigning holidays from a calendar config.
    def set_holidays(holidays)
      @holidays = parse_dates(holidays)
      return if (@holidays & @extra_working_dates).none?
      raise ArgumentError, 'Holidays cannot be extra working dates'
    end

    def set_extra_working_dates(extra_working_dates)
      @extra_working_dates = parse_dates(extra_working_dates)
    end

    # If no working days are provided in the calendar config, these are used.
    def default_working_days
      %w( mon tue wed thu fri )
    end
  end
end

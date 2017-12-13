require 'yaml'

module Business
  class Calendar
    class << self
      attr_accessor :additional_load_paths
    end

    def self.calendar_directories
      directories = @additional_load_paths || []
      directories + [File.join(File.dirname(__FILE__), 'data')]
    end
    private_class_method :calendar_directories

    def self.load(calendar)
      directory = calendar_directories.find do |dir|
        File.exists?(File.join(dir, "#{calendar}.yml"))
      end
      raise "No such calendar '#{calendar}'" unless directory

      yaml = YAML.load_file(File.join(directory, "#{calendar}.yml"))
      valid_keys = %w(holidays working_days)

      unless (yaml.keys - valid_keys).empty?
        raise "Only valid keys are: #{valid_keys.join(', ')}"
      end

      self.new(valid_keys.map{|k| [k.to_sym, yaml[k]]}.to_h)
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

    attr_reader :working_days, :holidays

    def initialize(config)
      set_working_days(config[:working_days])
      set_holidays(config[:holidays])
    end

    # Return true if the date given is a business day (typically that means a
    # non-weekend day) and not a holiday.
    def business_day?(date)
      date = date.to_date
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
    end

    # Internal method for assigning holidays from a calendar config.
    def set_holidays(holidays)
      @holidays = (holidays || []).map { |holiday| Date.parse(holiday) }
    end

    # If no working days are provided in the calendar config, these are used.
    def default_working_days
      %w( mon tue wed thu fri )
    end
  end
end


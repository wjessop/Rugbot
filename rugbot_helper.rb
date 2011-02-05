def ordinalize(number)
  if (11..13).include?(number.to_i % 100)
    "#{number}th"
  else
    case number.to_i % 10
      when 1; "#{number}st"
      when 2; "#{number}nd"
      when 3; "#{number}rd"
      else    "#{number}th"
    end
  end
end

module NumericTimeLength
  #
  # Converts an integer of seconds to days, hours, minutes + seconds
  # 
  # eg: 4200.to_time_length #=> "0 days 1 hours 10 mins and 0 secs"
  # 
  # Pass false to get the entire string returned, otherwise all
  # leading empty values are trimmed
  #
  def to_time_length trim_string=true
    amount = to_i
    other = 0

    a = [["sec", 60], "and", ["min", 60], ["hour", 24], ["day", 7], ["week", 52]].map do |j|
      # Skip "and"
      next(j) if j.is_a? String
      # Work out the math
      i = j.last
      if amount >= i
        amount, other = amount.divmod(i)
        r = other
      else
        r = amount
        amount = 0
      end

      # And build/return the string
      "#{r} #{j.first}#{"s" unless r == 1}#{"," unless %w(sec min).include?(j.first)}"
    end.reverse.join(" ")

    # Trim the string if needed
    if trim_string && m = a[/^(0 \w+, (?:and )?)+/]
      # This should probably fit in one regex, but fukkit. It works™
      a.gsub!(m, "")
    end

    a
  end
end
Numeric.send(:include, NumericTimeLength)


# Works out the *next* 3rd thursday of the month. ie, if we're past the 
# 3rd thursday in the current month it'll return the 3rd thursday of next month.
def nwrug_meet_for year, month
  beginning_of_month = Date.civil(year, month, 1)
  nwrug = beginning_of_month + (18 - beginning_of_month.wday)
  nwrug += 7 if beginning_of_month.wday > 4

  # Make sure we skip to the next month if we've gone past this month's meet
  if nwrug < Date.today
    if month == 12
      month = 1
      year += 1
    else
      month += 1
    end
    nwrug = nwrug_meet_for year, month
  end

  nwrug
end

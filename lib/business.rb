require 'rutie'

module Business
  Rutie.new(:business).init 'Init_business', __dir__

  Calendar = ::Calendar
end

class SecurityReport < ApplicationRecord
  enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
  belongs_to :company
end

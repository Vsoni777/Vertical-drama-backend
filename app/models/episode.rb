class Episode < ApplicationRecord
  belongs_to :series
  default_scope { order(:episode_number) }

end

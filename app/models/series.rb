class Series < ApplicationRecord
  has_many :episodes, dependent: :destroy
  has_one_attached :thumbnail_image

  validates :title, presence: true

  # Returns the best available thumbnail URL: Active Storage > string column > nil
  def thumbnail_url
    if thumbnail_image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(thumbnail_image, only_path: true)
    else
      self[:thumbnail].presence
    end
  end
end

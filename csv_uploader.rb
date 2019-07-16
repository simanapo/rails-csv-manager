# app\uploaders\csv_uploader.rb

class CsvUploader < CarrierWave::Uploader::Base
  # Choose what kind of storage to use for this uploader:

  if Rails.env.development? || Rails.env.test?
    # ローカル
    storage :file
  else
    # S3
    storage :fog
  end

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  # include CarrierWave::MimeTypes
  # process :set_content_type

  def store_dir
    "uploads/csvs"
  end

  def cache_dir
    "/tmp/uploads/csvs"
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w(csv)
  end

end

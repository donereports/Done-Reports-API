class Entry
  include DataMapper::Resource
  property :id, Serial

  belongs_to :report
  belongs_to :user

  property :date, DateTime
  property :type, String, :length => 100
  property :message, Text

  property :created_at, DateTime

  def api_hash(timezone)
    {
      :id => id,
      :content => message,
      :date => date.to_time.localtime(timezone.utc_offset).iso8601,
      :tags => []
    }
  end
end

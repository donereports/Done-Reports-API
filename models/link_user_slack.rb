class SlackUser
  include DataMapper::Resource
  belongs_to :user, :key => true
  belongs_to :slackserver, :key => true
  property :username, String, :length => 255
  property :created_at, DateTime
  property :updated_at, DateTime
end
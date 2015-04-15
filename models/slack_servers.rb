class Slackserver
  include DataMapper::Resource
  property :id, Serial

  belongs_to :org, :required => true

  property :team_domain, String, :length => 128
  property :token, String, :length => 128

  property :created_at, DateTime
  property :updated_at, DateTime

end
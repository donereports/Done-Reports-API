class Org
  include DataMapper::Resource
  property :id, Serial

  has n, :groups
  has n, :users, :through => :org_user
  has n, :ircservers
  has n, :slackservers
  has n, :commands

  property :name, String, :length => 128

  property :created_at, DateTime
end
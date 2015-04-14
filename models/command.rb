class Command
  include DataMapper::Resource
  property :id, Serial

  belongs_to :org, :required => false

  property :global, Boolean, :default => false

  property :command, String, :length => 50
  property :aliases, String, :length => 512 # Other commands that may be used to invoke this
  property :questions, Text # JSON encoded list of questions
  property :responses, Text # JSON encoded list of acknowlegements when someone enters a command
  property :report_title, String, :length => 255
  property :tips, Text # JSON encoded list of tips for the email report
  property :per_user, Boolean, :default => true # Whether this should show up under each user or in a global section at the bottom

  property :created_at, DateTime

  def api_hash
    {
      :command => command,
      :per_user => per_user,
      :aliases => (aliases ? JSON.parse(aliases) : nil),
      :title => report_title,
      :questions => (questions ? JSON.parse(questions) : nil),
      :responses => (responses ? JSON.parse(responses) : nil)
    }
  end

  def self.create_from_string(org, string) 
    command = Command.first :global => true, :command => string
    return command if command
    aliases = Command.all(:global => true).map{|c| c.aliases ? (JSON.parse(c.aliases).include?('block') ? c : nil) : nil}
    return aliases[0] if aliases
    command = Command.first :org => org, :command => string
    return command if command
    aliases = Command.all(:org => org).map{|c| c.aliases ? (JSON.parse(c.aliases).include?('block') ? c : nil) : nil}
    return aliases[0] if aliases
  end
end

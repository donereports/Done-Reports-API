class Group
  include DataMapper::Resource
  property :id, Serial

  belongs_to :org
  belongs_to :ircserver
  has n, :reports
  has n, :repos
  has n, :users, :through => :group_user

  property :token, String, :length => 128
  property :github_token, String, :length => 32
  property :name, String, :length => 128
  property :due_day, String, :length => 30
  property :due_time, DateTime   # Only the Time portion of this is used
  property :due_timezone, String, :length => 100
  property :send_reminder, Integer  # Number of hours before the deadline to send a reminder email

  property :email_group_members, Boolean, :default => true  # If true, report is sent to all members of the group individually
  property :email_recipient, String, :length => 255  # Additional email addresses to send the reports to

  property :irc_channel, String, :length => 100
  property :irc_channel_aliases, String, :length => 255, :default => ''

  property :github_organization, String, :length => 100
  property :github_access_token, String, :length => 255

  property :gitlab_api_url, String, :length => 255
  property :gitlab_private_token, String, :length => 255

  property :prompt_command, String, :length => 50
  property :prompt_from, DateTime, :default => '2000-01-01 09:00:00'
  property :prompt_to, DateTime, :default => '2000-01-01 18:00:00'

  property :created_at, DateTime

  def slug
    irc_channel.gsub(/^#/, '').downcase
  end

  def api_hash(is_admin=false)
    zone = Timezone::Zone.new :zone => due_timezone
    time = due_time.to_time.strftime("%H:%M")

    data = {
      :slug => slug,
      :name => name,
      :org_name => org.name,
      :channel => irc_channel,
      :channel_aliases => (irc_channel_aliases ? irc_channel_aliases.split(',') : []),
      :server => (ircserver ? ircserver.api_hash : nil),
      :timezone => due_timezone,
      :time => time,
      :date_created => created_at,
      :members => users.length
    }
    if is_admin
      data.merge!({
        :recipients => (email_recipient ? email_recipient.split(',') : []),
        :email_members => email_group_members,
        :is_admin => true
      })
    else
      data.merge!({
        :is_admin => false
      })
    end
    data
  end

  def send_irc_message(message)
    RestClient.post "#{ircserver.zenircbot_url}channel/#{URI.encode_www_form_component irc_channel}", :message => message, :token => ircserver.zenircbot_token
  end
end
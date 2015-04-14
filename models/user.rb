class User
  include DataMapper::Resource
  property :id, Serial

  has n, :commits
  has n, :groups, :through => :group_user
  has n, :orgs, :through => :org_user

  property :username, String, :length => 255
  property :email, String, :length => 255
  property :github_email, String, :length => 255
  property :github_username, String, :length => 255
  property :gitlab_email, String, :length => 255
  property :gitlab_username, String, :length => 255
  property :gitlab_user_id, Integer
  property :nicks, String, :length => 512
  property :slack_username, String, :length => 128
  property :active, Boolean, :default => true
  property :is_account_admin, Boolean, :default => false

  property :created_at, DateTime

  def email_for_org(org)
    return email if org.nil?
    ou = org_user.first(:org_id => org.id)
    return email if ou.nil?
    return email if ou.email.nil?
    ou.email
  end

  def avatar_url
    if !github_email.nil? && github_email != ''
      "https://secure.gravatar.com/avatar/#{Digest::MD5.hexdigest(github_email)}?s=40&d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png"
    elsif !email.nil? && email != ''
      "https://secure.gravatar.com/avatar/#{Digest::MD5.hexdigest(email)}?s=40&d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-user-420.png"
    else
      "https://a248.e.akamai.net/assets.github.com/images/gravatars/gravatar-user-420.png"
    end
  end

  # Returns all the reports this user contributed to in the given org
  def reports(org, before=false, count=10)
    ids = []
    repository.adapter.select('
      SELECT r.id
      FROM entries e
      JOIN reports r ON e.report_id = r.id
      WHERE user_id = ?
        AND r.group_id IN (SELECT id FROM groups WHERE org_id = ?)
        ' + (before ? 'AND r.id < ' + before.to_i.to_s : '') + '
      GROUP BY r.id
      ORDER BY e.date DESC
      LIMIT ?
    ', id, org.id, count).each do |report|
      ids << report
    end
    Report.all(:id => ids)
  end

  def api_hash
    {
      :username => username,
      :avatar => avatar_url
    }
  end
end
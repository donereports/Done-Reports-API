class Controller < Sinatra::Base

  def get_commands(org)
    commands = {}

    org.commands.each do |command|
      commands[command.command] = command.api_hash
    end

    Command.all(:global => true).each do |command|
      commands[command.command] = command.api_hash
    end

    commands
  end

  get '/api/orgs/:org/groups/:group/reports/:report' do
    auth_user = validate_access_token params[:access_token]
    org = validate_org_access! auth_user, params[:org]

    group = Group.first :irc_channel => "##{params[:group]}", :org => org
    if group.nil?
      halt json_error(200, {
        :error => 'group_not_found', 
        :error_description => 'The specified group was not found'
      })
    end

    report = Report.first :group => group, :id => params[:report]

    timezone = Timezone::Zone.new :zone => group.due_timezone
    time = group.due_time.to_time.localtime(timezone.utc_offset).strftime("%H:%M")

    users = []
    org.users(:order => [:username]).each do |user|
      if report.entries.all(:user => user).count > 0
        userdata = {
          user: user.api_hash,
          entries: {}
        }

        report.entries.all(:user => user).each do |entry|
          if userdata[:entries][entry.type].nil?
            userdata[:entries][entry.type] = []
          end
          userdata[:entries][entry.type] << entry.api_hash(timezone)
        end

        users << userdata
      end
    end

    json_response(200, {
      commands: get_commands(org),
      report: report.api_hash,
      users: users
    })
  end

  get '/api/orgs/:org/reports/users/:username' do
    auth_user = validate_access_token params[:access_token]
    org = validate_org_access! auth_user, params[:org]

    user = User.first :username => params[:username]

    # Find the latest n reports on this org for this user
    reports = []
    user.reports(org).each do |report|
      timezone = Timezone::Zone.new :zone => report.group.due_timezone
      entries = {}
      report.entries.all(:user => user).each do |entry|
        if entries[entry.type].nil?
          entries[entry.type] = []
        end
        entries[entry.type] << entry.api_hash(timezone)
      end

      reports << report.api_hash.merge({
        group: {
          name: report.group.name
        }, 
        entries: entries
      })
    end

    json_response(200, {
      commands: get_commands(org),
      user: user.api_hash,
      reports: reports
    })
  end

end

class Controller < Sinatra::Base

  def load_group(token)
    if token == "" or token == nil
      halt json_error(200, {:error => 'token_required', :error_description => 'Must provide a token'})
    end

    group = Group.first :token => token

    if group.nil?
      halt json_error(200, {:error => 'group_not_found', :error_description => 'No group found for the token provided'})
    end

    group
  end

  def load_user(username, group)
    user = group.org.users.first :username => username

    if user.nil?
      # Check if this is a real account or not
      test = User.first :username => username
      if test.nil?
        halt json_error(200, {
          :error => 'user_not_found', 
          :error_description => "No user was found for username \"#{username}\"", 
          :error_username => username
        })
      else
        halt json_error(200, {
          :error => 'user_not_in_org', 
          :error_description => "Sorry, \"#{username}\" is not in this organization",
          :error_username => username
        })
      end
    end

    if user.active == false
      halt json_error(200, {
        :error => 'user_disabled', 
        :error_description => "The user account for \"#{username}\" is disabled", 
        :error_username => username
      })
    end

    user
  end

  def load_server(token)
    if token == "" or token == nil
      halt json_error(200, {:error => 'token_required', :error_description => 'Must provide a token'})
    end

    server = Ircserver.first :zenircbot_configtoken => token

    if server.nil?
      halt json_error(200, {:error => 'not_found', :error_description => 'No server found for the token provided'})
    end

    server
  end

=begin
  `POST /api/report/new`

  * token - The token corresponding to the group
  * username - The user sending the report
  * type - past, future, blocking, hero, etc
  * message - The text of the report

  Post a new report. Automatically associated with the current open report for the group.
=end
  post '/api/report/new' do
    group = load_group params[:token]

    user = load_user params[:username], group

    if params[:type].nil? || params[:type] == ""
      halt json_error 200, {
        :error => 'missing_type',
        :error_description => 'The "type" field is required'
      }
    end

    report = Report.current_report(group)

    entry = report.create_entry :user => user, :type => params[:type], :message => params[:message]

    if entry.id
      json_response 200, {
        :group => {
          :name => group.name
        }, 
        :report => {
          :report_id => report.id, 
          :date_started => report.date_started
        },
        :entry => {
          :entry_id => entry.id,
          :username => entry.user.username,
          :date => entry.date,
          :type => entry.type,
          :message => entry.message
        }
      }
    else
      json_error 200, {
        :error => 'unknown_error',
        :error_description => 'There was a problem saving the entry'
      }
    end
  end

  post '/api/slack/post' do
    puts params.inspect

    server = Slackserver.first :team_domain => params[:team_domain], :token => params[:token]
    if !server
      halt json_error(200, {
        :error => 'org_not_found',
        :text => 'No organization was found for this slack team'
      })
    end

    group = Group.first :slackserver => server, :slack_channel => params[:channel_name]
    if !group
      halt json_error(200, {
        :error => 'channel_not_found',
        :text => 'No channel was found for this slack team'
      })
    end

    org = server.org

    # Check slack_username as well as username for matches
    slackuser = SlackUser.first :username => params[:user_name], :slackserver => server
    if slackuser.nil?
      user = org.users.first :username => params[:user_name]
      if user.nil?
        test = User.first :username => params[:user_name] if test.nil?

        if test.nil?
          halt json_error(200, {
            :text => "No user was found for username \"#{params[:user_name]}\""
          })
        else
          halt json_error(200, {
            :text => "Sorry, \"#{params[:user_name]}\" is not in this organization"
          })
        end
      end
    else
      user = slackuser.user
    end

    if user.active == false
      halt json_error(200, {
        :text => "Sorry, the user account for \"#{params[:user_name]}\" is disabled"
      })
    end

    report = Report.current_report(group)

    command = Command.create_from_string org, params[:trigger_word][1..-1]
    message = params[:text][(params[:trigger_word].length+1)..-1]
    entry = report.create_entry :user => user, :type => command.command, :message => message

    if entry.id
      responses = [
        "@#{params[:user_name]}: Got it!",
        "@#{params[:user_name]}: nice",
        "@#{params[:user_name]}: Nice!",
        "@#{params[:user_name]}: Ok!",
        "@#{params[:user_name]}: thanks!",
        "@#{params[:user_name]}: awesome!",
        "@#{params[:user_name]}: Awesome!",
      ]

      json_response 200, {
        :text => responses.sample
      }
    else
      json_error 200, {
        :error => 'unknown_error',
        :text => 'There was a problem saving the entry'
      }
    end
  end

=begin
  `POST /api/report/remove`

  * token - The token corresponding to the group
  * username - The username sending the report
  * message - The text of the report

  Remove a report. Only entries from an open report can be removed.
=end
  post '/api/report/remove' do
    group = load_group params[:token]

    user = load_user params[:username], group

    report = Report.current_report(group)

    entry = Entry.first :report => report, :user => user, :message => params[:message]

    if entry 
      entry.destroy
      json_response(200, {
        :result => 'success',
        :message => 'Entry was successfully deleted'
      })
    else
      json_error(200, {
        :error => 'entry_not_found',
        :error_description => 'No entry was found with the provided text'
      })
    end
  end

  # Returns a JSON config block for the group to be loaded into the IRC bot config
  get '/api/group/config' do
    group = load_group params[:token]

    data = {
      channel: group.irc_channel,
      timezone: group.due_timezone,
      users: []
    }

    group.users(:active => 1).each do |user|
      user_info = {
        username: user.username,
        nicks: (user.nicks ? user.nicks.split(',') : [])
      }
      data[:users] << user_info
    end

    json_response(200, data)
  end

  get '/api/bot/config' do
    server = load_server params[:token]

    data = {
      :groups => [],
      :commands => {}
    }

    server.groups(:active => 1).each do |group|
      groupInfo = {
        channel: group.irc_channel,
        aliases: group.irc_channel_aliases.split(','),
        timezone: group.due_timezone,
        token: group.token,
        :prompt => {
          :type => group.prompt_command || 'doing',
          :hr_from => (group.prompt_from ? group.prompt_from.to_time.strftime('%H').to_i : 9),
          :hr_to => (group.prompt_to ? group.prompt_to.to_time.strftime('%H').to_i : 18)
        },
        users: []
      }

      group.users(:active => 1).each do |user|
        userInfo = {
          username: user.username,
          nicks: (user.nicks ? user.nicks.split(',') : [])
        }
        groupInfo[:users] << userInfo
      end

      data[:groups] << groupInfo

      group.org.commands.each do |command|
        data[:commands][command.command] = command.api_hash
      end
    end

    Command.all(:global => true).each do |command|
      data[:commands][command.command] = command.api_hash
    end

    json_response 200, data
  end

end

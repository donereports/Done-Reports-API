def init(env=ENV['RACK_ENV']); end
require File.join('.', 'environment.rb')

namespace :db do
  task :bootstrap do
    init
    DataMapper.auto_migrate!
  end

  task :migrate do
    init
    DataMapper.auto_upgrade!
  end

  # Migration task when orgs were added
  task :add_orgs do
    puts 'Run the following SQL commands:'
    puts 'UPDATE groups SET org_id = account_id;'
    puts 'ALTER TABLE groups DROP COLUMN account_id;'

    User.all.each do |user|
      # Create an org for each user with a github username
      if !user.github_username.nil? && user.github_username != ''
        org = Org.first_or_create(:name => user.github_username)
        OrgUser.first_or_create({:user_id => user.id, :org_id => org.id}, {:is_admin => true})
      end

      # Add all the users to the appropriate accounts based on the groups they're currently in
      user.groups.orgs.each do |org|
        if org.name == user.username
          OrgUser.first_or_create({:user_id => user.id, :org_id => org.id}, {:is_admin => true})
        else
          user.orgs << org
        end
      end

      user.save
    end

    puts 'ALTER TABLE users DROP COLUMN account_id;'
    
  end
end

namespace :github do

  # Add a hook to just one repo
  task :add_hook, :org, :repo do |task, args|
    group = Group.first :github_organization => args[:org]

    if group.nil?
      puts "Could not find organization: #{args[:org]}"
    else
      repo = args[:repo].match(/github\.com\/([^\/]+\/[^\/]+)/)[1]

      if repo.nil?
        puts "Bad repo URL"
      else
        hooks_url = "https://api.github.com/repos/#{repo}/hooks"

        response = RestClient.post hooks_url, GithubHelper.hook_payload(group.github_token).to_json, :authorization => "Bearer #{group.github_access_token}"
        puts "Added hook to #{repo}"
        puts response

      end
    end
  end

  # Add the appropriate Github hooks to all repositories on the account
  task :add_hooks do

    Account.all.each do |account|

      account.groups.each do |group|
        if group.github_access_token

          continue = true
          page = 1

          while continue do
            response = RestClient.get "https://api.github.com/orgs/#{group.github_organization}/repos?page=#{page}&per_page=100", :authorization => "Bearer #{group.github_access_token}"
            repos = JSON.parse response

            skip = false

            repos.each do |repo|

              # skip = false if repo["name"] == "Munin-Plugins"
              # next if skip == true

              puts "========================"
              puts repo["name"]

              overwrite = true

              if overwrite
                # Remove all existing hooks
                json = RestClient.get repo["hooks_url"], :authorization => "Bearer #{group.github_access_token}"
                hooks = JSON.parse json
                hooks.each do |hook|
                  puts "Deleting #{hook["url"]}"
                  response = RestClient.delete hook["url"], :authorization => "Bearer #{group.github_access_token}"
                  #puts response
                end
                # Add the new hook
                response = RestClient.post repo["hooks_url"], GithubHelper.hook_payload(group.github_token).to_json, :authorization => "Bearer #{group.github_access_token}"
                puts "Added hook to #{repo['full_name']}"
                puts response
              else
                # Check if the hook is already there
                json = RestClient.get repo["hooks_url"], :authorization => "Bearer #{group.github_access_token}"
                hooks = JSON.parse json
                puts "Existing hooks: "
                puts hooks
                if hooks.select{|h| h['config']['url'] == hook_url}.length == 0
                  # Add the new hook
                  response = RestClient.post repo["hooks_url"], GithubHelper.hook_payload(group.github_token).to_json, :authorization => "Bearer #{group.github_access_token}"
                  puts response
                end
              end

              # Find all forks of the repo and add the hook to them
              # Will only have permission to add hooks if the repo is private
              if repo['private']
                response = RestClient.get "#{repo['url']}/forks", :authorization => "Bearer #{group.github_access_token}"
                forks = JSON.parse response

                if forks.length > 0
                  # Add the new hook
                  forks.each do |fork|
                    begin
                      response = RestClient.post fork["hooks_url"], GithubHelper.hook_payload(group.github_token).to_json, :authorization => "Bearer #{group.github_access_token}"
                      puts "Added hook to #{fork['full_name']}"
                    rescue
                    end
                    puts response
                  end
                end
              end

            end

            page = page + 1
            continue = false if repos.length == 0
          end #while

        end
      end #group
    end #account

  end # task :add_hooks

  task :find_forks do

    Account.all.each do |account|

      account.groups.each do |group|
        if group.github_access_token

          org_repos = []
          continue = true
          page = 1

          while continue do
            response = RestClient.get "https://api.github.com/orgs/#{group.github_organization}/repos?page=#{page}&per_page=100", :authorization => "Bearer #{group.github_access_token}"
            repos = JSON.parse response

            skip = false

            repos.each do |repo|
              org_repos << repo
            end

            page = page + 1
            continue = false if repos.length == 0
          end #while

          org_repos = org_repos.sort_by { |k| k['name'] }

          # puts org_repos.map {|k| k["name"]}
          puts "Found #{org_repos.length} repositories"

          org_repos.each do |repo|
            response = RestClient.get "https://api.github.com/repos/#{repo['full_name']}/forks", :authorization => "Bearer #{group.github_access_token}"
            forks = JSON.parse response

            if forks.length > 0
              puts repo['name']
              puts forks.map{ |k| "    #{k['html_url']}" }.join("\n")
              puts
            end
          end

        end
      end #group
    end #account

  end
end

namespace :report do

  def ses_client
    ses = AWS::SES::Base.new(
      :access_key_id     => SiteConfig.aws_key_id,
      :secret_access_key => SiteConfig.aws_secret
    )
  end

  def send_report(report)
    ses = ses_client
    group = report.group
    org = group.org

    report_types = [
      {:type => 'doing',    :title => 'What are you working on?', :entries => []},
      {:type => 'done',     :title => 'What did you do?', :entries => []},
      {:type => 'future',   :title => 'What is your plan for tomorrow?', :entries => []},
      {:type => 'blocking', :title => 'What is blocking you?', :entries => []},
      {:type => 'hero',     :title => 'Who is your hero?', :entries => []},
      {:type => 'unknown',  :title => 'Other Updates', :entries => []},
    ]
    help_sentences = {
      'doing' => [
        'To share things in progress, try "!doing"',
        'If you\'re working on something but not done yet, you can say "!doing something"',
      ],
      'done' => [
        'Say "!done wrote a blog post" to share what you\'ve finished today',
        'Say "!done ticket #445" to say what you finished today',
      ],
      'future' => [
        'You can say "!todo take over the world" to share what you plan on working on tomorrow',
        'To share what you plan to do tomorrow, you can say things like "!todo more testing"',
      ],
      'blocking' => [
        'If you\'re stuck on something, say "!blocking Internet is down" to share it',
        'If something is blocking you, let everyone know by saying "!blocking not enough time"',
      ],
      'hero' => [
        'Did someone make your day? Thank them with "!hero Loqi for being awesome"',
        '"!hero Loqi for always listening" is a great way to make someone\'s day :)',
      ],
      'quote' => [
        'Did someone say something funny? Jot it down with !quote "Some super funny text" -a funny guy',
        'Use \'!quote "Some super funny text" -a funny guy\' to jot down an awesome quote from someone"',
        'Did you hear a useful quote at a conference? Share it with \'!quote "We promise not to screw it up." -marissa meyer',
      ]
    }

    # Create the object that will be passed into the email erb template
    email_data = {
      :group => nil,
      :report => nil,
      :report_localtime => nil,
      :users => [],
      :quotes => []
    }

    puts "  Group '#{group.name}'"
    email_data[:group] = group

    puts "    Report ##{report.id}"
    email_data[:report] = report

    zone = Timezone::Zone.new :zone => group.due_timezone

    # If the current time is past the due date, close the report and send an email summary
    if DateTime.now > report.date_due
      if report.date_completed.nil?
        report.date_completed = DateTime.now
        report.save
      end
      email_data[:report_localtime] = report.date_completed.to_time.localtime(zone.utc_offset)

      # Each user gets their own section
      org.users.each do |user|
        # Only include this user in the email if they have some entries
        if report.entries.all(:user => user).count > 0

          puts "      #{user.username}"
          num_entries = 0

          # Gather all the entries for this report, grouped by type
          types = JSON.parse report_types.to_json, :symbolize_names => true  # Hack around needing to make a deep clone
          types.each do |type|
            entries = report.entries.all(:type => type[:type], :user => user)
            if entries.count > 0 
              puts "        #{type[:title]}"
              entries.each do |entry| 
                puts "          * #{entry.message}"
                num_entries += 1
                type[:entries] << entry
              end
            end
          end

          # Find any repos this user committed to during the report period
          repos = Repo.all(:commits => Commit.all(:user => user, 
            :date.gt => report.date_started, 
            :date.lt => report.date_completed))

          if repos.count > 0
            type = {
              :type => 'commits', :title => 'Active Projects', :entries => []
            }
            puts "        Commits"
            repos.each do |r|
              puts "          * #{r.name}"
              type[:entries] << r unless r.name.to_s == ""
            end
            types << type
          end

          if num_entries > 0
            email_data[:users] << {
              :user => user,
              :types => types
            }
          end

        end
      end

      quotes = report.entries.all(:type => 'quote')
      if quotes.count > 0
        email_data[:quotes] = quotes
      end

      if email_data[:users].count + email_data[:quotes].count > 0

        recipients = []

        recipients = group.email_recipient.split(",") unless group.email_recipient.nil?

        if group.email_group_members
          group.users.each do |user| 
            recipients << user.email
          end
        end

        # Find all of the types that are not used in this report
        types_used = email_data[:users].map{|u| u[:types].map{|t| t[:entries].length > 0 ? t[:type] : nil}.compact}.flatten
        types_unused = report_types.map{|t| t[:type]} - types_used

        # Choose one to highlight in this email
        highlight_type = types_unused.sample

        # Choose a random sentence for this type and include in the footer of the email
        if help_sentences[highlight_type] && [0,1].sample == 0
          email_data[:help_text] = help_sentences[highlight_type].sample
        else
          email_data[:help_text] = nil
        end

        email_data[:recipients] = recipients

        # Merge the data with the email template in email.erb
        puts "------"
        template = Erubis::Eruby.new File.read 'views/email.erb'
        email_html = template.result email_data
        puts email_html
        puts "------"

        template_text = Erubis::Eruby.new File.read 'views/email_text.erb'
        email_text = template_text.result email_data
        puts email_text
        puts "------"

        puts "Sending to: "
        puts recipients

        # Send the email via Amazon SES now
        ses.send_email :to => recipients,
          :source => 'done@donereports.com',
          :subject => "Report for #{group.name}",
          :text_body => email_text,
          :html_body => email_html

      else
        puts "No data in this report, not sending"
      end

    # If the current time is past the reminder time, send out reminder emails
    elsif report.date_reminder != nil && DateTime.now > report.date_reminder
      report.date_reminder_sent = DateTime.now
      report.save

    else
      puts "      In progress"
    end

  end

  task :cron do
    # This is a cron task that runs every 5 minutes.

    # Send out any reminders for deadlines coming soon.
    # Send out emails for any reports that are open and past the deadline.

    Org.all.each do |org|
      puts "Processing org '#{org.name}'"

      org.groups.each do |group|

        # Find an open report, if there are none, then this will create one
        report = Report.current_report(group)

        send_report report

      end # end group
    end # end org
  end

  task :send, :id do |task, id|

    report = Report.first :id => id[:id]
    if report.nil?
      raise "Report #{id} not found"
    end

    send_report report
  end

  task :test do
    org = Org.first :id => 1
    group = Group.first :id => 27

    report = Report.current_report(group)

    puts report.inspect
  end
end

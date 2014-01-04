def init(env=ENV['RACK_ENV']); end
require File.join('.', 'environment.rb')

namespace :db do
  task :bootstrap do
    init
    DataMapper.auto_migrate!

    # INSERT INTO `commands` (`id`, `command`, `aliases`, `questions`, `responses`, `created_at`, `org_id`, `global`, `report_title`, `tips`, `per_user`)
    # VALUES
    #   (1, 'done', NULL, '[\"What did you finish?\",\"Did you finish anything?\"]', '[\":nick: Nicely done.\",\":nick: Nicely done!\",\":nick: Nicely done!\",\":nick: great!\"]', NULL, NULL, 1, 'What have you done? (!done)', '[\"Say \\\"!done wrote a blog post\\\" to share what you\'ve finished today\",\"Say \\\"!done ticket #445\\\" to say what you finished today\"]', 1),
    #   (2, 'doing', NULL, '[\"What have you been working on?\",\"What are you working on?\"]', '[\":nick: great, thanks!\",\":nick: Great, thanks!\",\":nick: Thanks!\",\":nick: thanks!\",\"Thanks, :nick!\",\"Thanks, :nick\"]', NULL, NULL, 1, 'What have you been doing? (!doing)', '[\"To share things in progress, try \\\"!doing\\\"\",\"If you\'re working on something but not done yet, you can say \\\"!doing something\\\"\"]', 1),
    #   (3, 'quote', NULL, NULL, '[\":nick: Good one!\",\":nick: good one!\",\":nick: lol!\",\":nick: haha, awesome\",\":nick: haha, awesome!\"]', NULL, NULL, 1, '!quote', '[\"Did someone say something funny? Jot it down with !quote \\\"Some super funny text\\\" -a funny guy\",\"Use \'!quote \\\"Some super funny text\\\" -a funny guy\\\' to jot down an awesome quote from someone\",\"Did you hear a useful quote at a conference? Share it with \'!quote \\\"We promise not to screw it up.\\\" -marissa meyer\'\"]', 0),
    #   (4, 'hero', NULL, '[\"Who is your hero and what did they do?\"]', '[\":nick: sweet!\",\":nick: Sweet!\",\":nick: yeah!!\",\":nick: awesome!\"]', NULL, NULL, 1, 'Who is your hero? (!hero)', '[\"Did someone make your day? Thank them with \\\"!hero Loqi for being awesome\\\"\",\"\\\"!hero Loqi for always listening\\\" is a great way to make someone\'s day :)\"]', 1),
    #   (5, 'share', '[\"shared\"]', NULL, '[\":nick: sweet!\",\":nick: Sweet!\",\":nick: yeah!\",\":nick: awesome!\"]', NULL, NULL, 1, '!share', '[\"Read any good links today? Share them with \\\"!share http://opensourcebridge.org/sessions/1106\\\"\",\"\\\"!share http://opensourcebridge.org/sessions/1106\\\" is a great way share interesting links\"]', 0),
    #   (6, 'todo', NULL, '[\"What are you going to do tomorrow?\",\"What\'s your plan for tomorrow?\"]', NULL, NULL, NULL, 1, 'What is your plan for tomorrow? (!todo)', '[\"You can say \\\"!todo take over the world\\\" to share what you plan on working on tomorrow\",\"To share what you plan to do tomorrow, you can say things like \\\"!todo more testing\\\"\"]', 1),
    #   (7, 'blocking', '[\"blocked\"]', '[\"What are you stuck on? Or \'not stuck on anything\' is fine too.\",\"What is blocking you? \'Not blocked\' is fine too.\",\"Are you blocked on anything?\"]', '[\":nick: Sorry to hear that!\",\":nick: I will remember that\",\":nick: I hope it is resolved soon!\",\":nick: :(\",\":nick: Thanks for letting me know!\"]', NULL, NULL, 1, 'What is blocking you? (!block)', '[\"If you\'re stuck on something, say \\\"!blocking Internet is down\\\" to share it\",\"If something is blocking you, let everyone know by saying \\\"!blocking not enough time\\\"\"]', 1);

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
    GithubTasks.add_hook args[:org], args[:repo]
  end

  # Add the appropriate Github hooks to all repositories on all accounts
  task :add_hooks do
    GithubTasks.add_all_hooks
  end # task :add_hooks

  task :find_forks do
    GithubTasks.find_forks
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

    report_types = []
    help_sentences = {}

    (group.org.commands + Command.all(:global => true)).each do |command|
      if command.per_user
        report_types << {
          :type => command.command,
          :title => command.report_title,
          :entries => []
        }
      end
      help_sentences[command.command] = JSON.parse command.tips
    end

    # Create the object that will be passed into the email erb template
    email_data = {
      :group => nil,
      :report => nil,
      :report_localtime => nil,
      :users => [],
      :quotes => [],
      :shares => []
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

      # Find all users in the org so that users not in a group also show up
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

          # Find any repos this user committed to during the report period, restricted to the org of this report
          repos = org.groups.repos.all(:commits => Commit.all(:user => user, 
            :date.gt => report.date_started, 
            :date.lt => report.date_completed))

          if repos.count > 0
            type = {
              :type => 'commits', :title => 'Active GitHub Projects', :entries => []
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

      email_data[:global] = []

      (group.org.commands + Command.all(:global => true)).each do |command|
        if !command.per_user
          entries = report.entries.all(:type => command.command)
          if entries.count > 0
            email_data[:global] << {
              :type => command.command,
              :title => command.report_title,
              :entries => entries
            }
          end
        end
      end

      if email_data[:users].count + email_data[:global].count > 0

        recipients = []

        recipients = group.email_recipient.split(",") unless group.email_recipient.nil?

        if group.email_group_members
          # Add all group members to the recipient list
          group.users.each do |user| 
            recipients << user.email_for_org(org)
          end

          # Also add anybody else who submitted to the report
          email_data[:users].each do |user|
            recipients << user[:user].email_for_org(org)
          end

          # Catches people who only submitted global entries (not per-user types like !quote)
          email_data[:global].each do |type|
            type[:entries].each do |entry|
              recipients << entry.user.email_for_org(org)
            end
          end

          # De-dupe
          recipients.uniq!
        end

        # Find all of the types that are not used in this report
        types_used = email_data[:users].map{|u| u[:types].map{|t| t[:entries].length > 0 ? t[:type] : nil}.compact}.flatten
        email_data[:global].each do |type|
          types_used << type[:type] if type[:entries].length > 0
        end
        types_unused = help_sentences.keys - types_used

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

        template_text = Erubis::Eruby.new File.read 'views/email.txt.erb'
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


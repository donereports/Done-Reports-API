class Controller < Sinatra::Base

  post '/api/github_hook/add' do
    group = load_group params[:token]

    if params[:repo_url].nil?
      return json_error(400, {
        error: 'missing_field',
        error_description: 'Parameter `repo_url` is required'
      })
    end

    if (match=params[:repo_url].match(/https?:\/\/github\.com\/([^\/]+\/[^\/]+)/)) == nil
      return json_error(400, {
        error: 'invalid_repo_url',
        error_description: 'Repo URL must be a Github URL like https://github.com/user/repo'
      })
    end
    repo = match[1]

    hooks_url = "https://api.github.com/repos/#{repo}/hooks"

    # Check for existing hooks
    hook_url = GithubHelper.hook_url(group.github_token)

    begin
      json = RestClient.get hooks_url, :authorization => "Bearer #{group.github_access_token}"
      hooks = JSON.parse json
      if hooks.select{|h| h['config']['url'] == hook_url}.length == 0
        # Add the new hook
        response = RestClient.post hooks_url, GithubHelper.hook_payload(group.github_token).to_json, :authorization => "Bearer #{group.github_access_token}"
        puts "Added hook to #{repo}"
        puts response
        added = true
      else
        added = false
      end
    rescue
      return json_error(200, {
        error: 'github_error',
        error_description: "There was an error saving the Github hook. Make sure the linked Github account has permission to access this repository"
      })
    end

    json_response(200, {
      group_name: group.name,
      repo_url: params[:repo_url],
      repo: repo,
      added: added
    })
  end

  # Handles all Github hooks http://developer.github.com/v3/repos/hooks/
  # Create a hook:
  # curly -H "Authorization: Bearer XXXX" https://api.github.com/repos/USER/REPO/hooks -d '{"name":"web","active":true,"events":["commit_comment","create","delete","download","follow","fork","fork_apply","gist","gollum","issue_comment","issues","member","public","pull_request","pull_request_review_comment","push","status","team_add","watch"],"config":{"url":"https://status-report.geoloqi.com/hook/github?token=XXXX","content_type":"json"}}' -H "Content-type: application/json"

  post '/hook/github' do
    event = env['HTTP_X_GITHUB_EVENT']

    if event.nil?
      return json_error(400, {
        error: 'missing_type',
        error_description: 'Expecting an X-Github-Event HTTP header but none was present'
      })
    end

    if params['payload']
      body = params['payload']
    else
      body = request.body.read
    end

    begin
      json = JSON.parse(body)
    rescue => e
      return json_error(400, {
        error: 'bad_request',
        error_description: e
      })
    end

    if params[:token]
      group = Group.first :github_token => params[:token]
    end

    if group.nil?
      return json_error(403, {
        error: 'forbidden',
        error_description: "No group found for token: #{params[:token]}"
      })
    end

    commits = create_commit_from_github_payload group, event, json

    if commits.nil?
      puts "-======================================-"
      puts "No entry found for payload"
      jj json
      return json_response 200, {result: "no_data"}
    end

    if !commits.is_a? Array
      commits = [commits]
    end

    commits.each do |commit|
      if commit.irc_message
        begin
          group.send_irc_message commit.irc_message
        rescue => e
          puts "Exception!"
          puts e
        end
      end
    end

    json_response 200, {result: "ok"}
  end

# Old Github post hook
=begin
  post '/hooks/github' do
    payload = JSON.parse(params[:payload])

    if params[:github_token]
      group = Group.first :github_token => params[:github_token]
    else
      # Hack because I forgot to set up the github hook with the token and need to write a script to clean it up later
      group = Group.get 1
    end

    if group.nil?
      return json_error(200, {:error => 'group_not_found', :error_description => 'No group found for the token provided'})
    end

    # Look for a matching project by the repo URL in the payload
    repo = Repo.first_or_create(:link => payload["repository"]["url"], :group => group)
    if repo
      payload["commits"].each do |commit|
        puts commit.inspect
        # Attempt to map the commit to a user account. Will return nil if not found
        user = User.first :account_id => group.account_id, :github_email => commit["author"]["email"]
        Commit.create(
          :repo => repo,
          :link => commit["url"],
          :text => commit["message"],
          :date => Time.parse(commit["timestamp"]),
          :user_name => commit["author"]["name"],
          :user_email => commit["author"]["email"],
          :user => user
        )
      end
    end
    json_response 200, {:result => 'ok'}
  end
=end

  def create_commit_from_github_payload(group, type, payload)
    # Most events have a repository.html_url key, except for "push" events. In that case, repo will be nil.
    repo = Repo.first_or_create(:link => payload["repository"]["html_url"], :group => group)
    now = Time.now

    if payload["sender"]
      username = payload["sender"]["login"]
      user = User.first(:github_username => username)
    else
      username = ""
      user = nil
    end

    case type
    when "commit_comment"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: payload["comment"]
      })
    when "create"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} created #{payload["ref_type"]} #{payload["ref"]}"
      })
    when "delete"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} deleted #{payload["ref_type"]} #{payload["ref"]}"
      })
    when "download"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} created download #{payload["download"]["name"]}",
        link: payload["download"]["html_url"]
      })
    when "follow"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} followed #{payload["target"]["login"]}"
      })
    when "fork"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} forked #{payload["forkee"]["full_name"]}",
        link: payload["forkee"]["html_url"]
      })
    when "fork_apply"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} applied fork #{payload["head"]}"
      })
    when "gist"
      description = ""
      if payload["gist"]["description"]
        description = ": #{payload["gist"]["description"]}"
      end
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} #{payload["action"]}d gist#{description}",
        link: payload["gist"]["url"]
      })
    when "gollum"
      events = []
      payload["pages"].each do |page|
        events << Commit.create({ 
          type: type,
          repo: repo,
          user: user,
          date: now,
          text: "#{username} #{page["action"]} \"#{page["page_name"]}\"",
          link: page["html_url"]
        })
      end
      events
    when "issue_comment"
      summary = Sanitize.clean(payload["comment"]["body"])[0..140]
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} #{payload["action"]} comment: #{summary}...",
        link: payload["issue"]["html_url"]
      })
    when "issues"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} #{payload["action"]} issue ##{payload["issue"]["number"]}: #{payload["issue"]["title"]}",
        link: payload["issue"]["html_url"]
      })
    when "member"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} was #{payload["action"]} to the repository"
      })
    when "public"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} open sourced the repository!"
      })
    when "pull_request"
      details = []
      details << "#{payload["pull_request"]["commits"]} commits" if payload["pull_request"]["commits"] > 0
      details << "#{payload["pull_request"]["changed_files"]} changed files" if payload["pull_request"]["changed_files"] > 0
      details_str = ""
      if details.count > 0
        details_str = " (#{details.join(', ')})"
      end

      events = []
      events << Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} #{payload["action"]} pull request ##{payload["number"]}#{details_str}",
        link: payload["pull_request"]["html_url"]
      })
      if payload["mergeable"] == false
        events << DummyCommit.create({
          repo: repo,
          text: "Pull request ##{payload["pull_request"]["number"]} cannot be safely merged!",
          link: payload["pull_request"]["html_url"]
        })
      end
      events

    when "pull_request_review_comment"
      summary = Sanitize.clean(payload["comment"]["body"])[0..140]
      if payload["comment"]["_links"]
        comment_url = payload["comment"]["_links"]["html"]["href"]
      else
        comment_url = ''
      end
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{username} commented #{summary}",
        link: comment_url
      })
    when "push"
      events = []
      repo = nil
      user = nil
      author = nil
      payload["commits"].each do |commit|
        if commit["distinct"]
          repo_url = commit["url"].match(/https?:\/\/github\.com\/[^\/]+\/[^\/]+/)[0]
          repo = Repo.first_or_create :link => repo_url, :group => group
          user = User.first(:github_email => commit["author"]["email"])
          events << Commit.create({
            type: "commit",
            repo: repo,
            user: user,
            date: now,
            user_name: commit["author"]["name"],
            user_email: commit["author"]["email"],
            text: "#{commit["author"]["email"]} committed: \"#{commit["message"]}\"",
            link: commit["url"]
          })
        end
        author = commit["author"]["email"]
      end
      events << Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{user ? user.github_username : author} pushed #{payload["commits"].length} commits"
      })
      events
    when "team_add"
      text = "#{username} "
      if payload["user"] and payload["repo"]
        text += "added #{payload["user"]["login"]} and #{payload["repo"]["full_name"]}"
      elsif payload["user"]
        text += "added #{payload["user"]["login"]}"
      elsif payload["repo"]
        text += "added #{payload["repo"]["full_name"]}"
      end
      text += " to team #{payload["team"]["name"]}"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: text,
        link: payload["team"]["url"]
      })
    when "watch"
      Commit.create({
        type: type,
        repo: repo,
        user: user,
        date: now,
        text: "#{payload["sender"]["login"]} #{payload["action"]} watching #{payload["repository"]["full_name"]}",
        link: repo.link
      })
    end
  end

end

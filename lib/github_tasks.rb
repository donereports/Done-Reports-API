class GithubTasks

  def self.add_hook(org, repo_url)
    group = Group.first :github_organization => org

    if group.nil?
      puts "Could not find organization: #{org}"
    else
      repo = repo_url.match(/github\.com\/([^\/]+\/[^\/]+)/)[1]

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

  def self.add_all_hooks
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
  end

  def self.find_forks
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
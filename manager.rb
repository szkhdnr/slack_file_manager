require 'open-uri'
require 'slack'
require 'active_support/all'

SLACK_OAUTH_TOKEN = 'YOUR_SLACK_OAUTH_ACCESS_TOKEN'.freeze

def check_response(response)
  if response['ok'] == false
    puts 'Failed to communicate with Slack!'
    puts '=====Traceback===='
    puts "OAuth Token=#{SLACK_OAUTH_TOKEN}"
    puts response['error']
    puts '=================='

    exit(1)
  end
end

def download_file(url_private_download, file_name, output_dir = './')
  authorization_header = "Bearer #{SLACK_OAUTH_TOKEN}"
  output_path = File.join(output_dir, file_name)

  begin
    open(output_path, 'wb') do |local_file|
      open(url_private_download, 
       'Authorization' => authorization_header) do |remote_file|
        # https://api.slack.com/types/file#authentication
        local_file.write(remote_file.read)
      end
    end
  rescue => error
    puts "Error occured while donwloading #{url_private_download}."
    puts '=====Traceback===='
    puts error.message
    puts '=================='
    return false
  end

  true
end

def main
  # downalod and delete files which uploaded before 1 years.
  ts_to = Time.now - 1.year
  unix_ts_to = ts_to.to_i
  # https://api.slack.com/methods/files.list
  puts "Delete files which created before #{ts_to}(UNIX TIME:#{unix_ts_to})"

  # test authentication
  print 'Trying OAuth Authentication...'
  Slack.configure do |config|
    config.token = SLACK_OAUTH_TOKEN
  end
  check_response(Slack.auth_test)
  print("OK\n")

  print "Retrievaling Slack files(ts_to:#{unix_ts_to})..."
  slack_files_list = Slack.files_list({'ts_to': unix_ts_to})
  check_response(slack_files_list)
  print("OK\n")
  puts "Target files num: #{slack_files_list['paging']['total']}"

  slack_files_list['files'].each do |remote_file_info|
    file_id = remote_file_info['id']
    file_name = remote_file_info['name']
    created_at = remote_file_info['created'] # 'timestamp' is deprecated!
    url_private_download = remote_file_info['url_private_download']

    if url_private_download == nil # when file is dropbox shared
      puts "Skipped=> #{file_name} is Dropbox shared file."
      next
    end

    print("Downloading=> #{file_name}(Created at #{Time.at(created_at)})...")
    if download_file(url_private_download, file_name)
      print("Done\n")
      print("Deleting=> #{file_name}(Created at #{Time.at(created_at)})...")
      if Slack.files_delete({'file': file_id})['ok']
        print("Done\n")
      else
        print("Failed!\n")
      end
    else
      print("Failed!\n")
    end
  end

  puts 'Done!'
end

main if $PROGRAM_NAME == __FILE__

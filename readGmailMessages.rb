require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'fileutils'

# Need to install this 'google-api-client'
APPLICATION_NAME = 'Gmail API Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.pwd, '.credentials',"gmail-api-credentials.json")
SCOPE = 'https://mail.google.com/'
ENV['SSL_CERT_FILE'] = '/usr/local/etc/openssl/certs/cacert.pem'
##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization request via InstalledAppFlow.
# If authorization is required, the user's default browser will be launched
# to approve the request.
#
# @return [Signet::OAuth2::Client] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  file_store = Google::APIClient::FileStore.new(CREDENTIALS_PATH)
  storage = Google::APIClient::Storage.new(file_store)
  auth = storage.authorize

  if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
    app_info = Google::APIClient::ClientSecrets.load(CLIENT_SECRETS_PATH)
    flow = Google::APIClient::InstalledAppFlow.new({
      :client_id => app_info.client_id,
      :client_secret => app_info.client_secret,
      :scope => SCOPE})
    auth = flow.authorize(storage)
    puts "Credentials saved to #{CREDENTIALS_PATH}" unless auth.nil?
  end
  auth
end

def get_details(id)
# Initialize the API
  client = Google::APIClient.new(:application_name => APPLICATION_NAME)
  client.authorization = authorize
  gmail_api = client.discovered_api('gmail', 'v1')
  result = client.execute(
      :api_method => gmail_api.users.messages.get,
      :parameters => {'userId' => 'me', 'id' => id})
  data = JSON.parse(result.body)

  { subject: get_gmail_attribute(data, 'Subject'),
    from: get_gmail_attribute(data, 'From'),
    date: get_gmail_attribute(data, 'Date'),
    body: get_email_body(result)}
end

def get_gmail_attribute(gmail_data, attribute)
  headers = gmail_data['payload']['headers']
  array = headers.reject { |hash| hash['name'] != attribute }
  array.first['value']
end

def get_email_body(result)
  result.data.payload.parts.at(0).body.data
end

def delete_messages(query)
  # Initialize the API
  client = Google::APIClient.new(:application_name => APPLICATION_NAME)
  client.authorization = authorize
  gmail_api = client.discovered_api('gmail', 'v1')

# Show the user's message list
  result = client.execute(
      :api_method => gmail_api.users.messages.list,
      :parameters => {'userId' => 'me', 'labelIds' => 'INBOX', 'maxResults' => '10000', 'q' => query})

  result.data.messages.each do |message|
    delete_message(message.id)
  end
end

def delete_message(id)
  # Initialize the API
  client = Google::APIClient.new(:application_name => APPLICATION_NAME)
  client.authorization = authorize
  gmail_api = client.discovered_api('gmail', 'v1')

# Show the user's message list
  result = client.execute(
      :api_method => gmail_api.users.messages.delete,
      :parameters => {'userId' => 'me', 'id' => id})
  puts result
end

def get_emails(query, maxResults)
  # Initialize the API
  client = Google::APIClient.new(:application_name => APPLICATION_NAME)
  client.authorization = authorize
  gmail_api = client.discovered_api('gmail', 'v1')

# Show the user's message list
  result = client.execute(
      :api_method => gmail_api.users.messages.list,
      :parameters => {'userId' => 'me', 'labelIds' => 'INBOX', 'maxResults' => maxResults, 'q' => query})

  emails = []
  result.data.messages.each do |message|
    email_details = get_details(message.id)
    emails.push(email_details)
  end
  return emails
end


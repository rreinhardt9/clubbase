require 'sinatra'
require 'oauth2'
require 'securerandom'
require 'uri'

enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html

    def signed_in?
      !session[:access_token].nil?
    end

    def pretty_json(json)
      JSON.pretty_generate(json)
    end
  end

def basecamp_client
  OAuth2::Client.new(
    ENV['CLIENT_ID'],
    ENV['CLIENT_SECRET'],
    site: "https://3.basecampapi.com/",
    authorize_url: "#{ENV['BASECAMP_OAUTH']}authorization/new",
    token_url: "#{ENV['BASECAMP_OAUTH']}authorization/token"
  )
end

def access_token
  OAuth2::AccessToken.new(basecamp_client, session[:access_token])
end

get '/' do
  erb :home
end

get '/sign_in' do

  redirect basecamp_client.auth_code.authorize_url(
    redirect_uri: url('/oauth2/callback'),
    type: :web_server
  )
end

get '/oauth2/callback' do
  token = basecamp_client.auth_code.get_token(
    params[:code],
    redirect_uri: url('/oauth2/callback'),
    type: :web_server
  )

  session[:access_token] = token.token
  session[:refresh_token] = token.refresh_token

  redirect '/'
end

post '/add_ch_key' do
  session[:ch_key] = params[:ch_key]

  redirect '/'
end

get '/transfer_todoset' do
  erb :transfer_todoset
end

get '/log_out' do
  session[:access_token] = nil
  session[:refresh_token] = nil
  session[:ch_key] = nil
  redirect '/'
end

post '/move_todos' do
  # begin
    todoset_url = params[:bc_todoset_uri]
    path = "#{todoset_url[1]}/buckets/#{todoset_url[3]}/todosets/#{todoset_url[5]}/todolists.json"

    @stories = []
    lists_response = access_token.get(path)
    JSON.parse(lists_response.body).each do |list|
      todos = access_token.get(list["todos_url"])
      JSON.parse(todos.body).each do |todo|
        @stories << {
          name: "[#{list["title"]}] #{todo["title"]}",
          description: todo["description"],
          project_id: params[:ch_project_id].to_i,
          epic_id: params[:ch_epic_id].to_i,
          external_id: todo["id"].to_s,
          external_tickets: [
            {external_id: todo["id"].to_s, external_url: todo["app_url"]}
          ]
        }
      end

    end
    @story_json = {stories: @stories}.to_json
    @json = JSON.parse(lists_response.body)
    @ch_response = Faraday.post(
      "https://api.clubhouse.io/api/v3/stories/bulk?token=#{session[:ch_key]}",
      @story_json,
      "Content-Type" => "application/json"
    )
    redirect '/'
  # rescue OAuth2::Error => _e
  #   erb :error
  # end
end


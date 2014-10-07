require 'net/https'
require 'json'

get '/auth/login' do
  haml :auth
end

post '/auth/check' do
  user = params[:user]
  ans = sql_do('SELECT user_id, is_admin FROM users WHERE name=$1', [user]).values
  if ans.size >0 then user_id, is_admin = ans[0]
  else halt 500, 'No such user'
  end
  session[:user_id] = user_id
  session[:admin] = (is_admin == 't') ?  true : false
  session[:mail] = user
end

get '/auth/get_mail' do
  session[:mail] ||= 'null'
  halt 200, session[:mail]
end

post '/auth/auth' do
  uri = URI.parse 'https://verifier.login.persona.org/verify'
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Post.new uri.request_uri

  my_domain = "#{request.secure? ? 'https' : 'http'}://#{request.host}#{request.path}"

  req.set_form_data({:assertion => params[:assertion], :audience => my_domain})

  resp = http.request req

  out = JSON.parse(resp.body)

  if out['email'] == session[:mail] && out['status'] == 'okay'
    session[:auth] = 'Okay'
    redirect to '/'
  else
    halt 500, 'Authorization with Persona failed.'
  end
end

get '/auth/logout' do
  session.clear
  redirect to '/'
end

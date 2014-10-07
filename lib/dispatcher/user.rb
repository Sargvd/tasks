get '/user', :authorized => true do
  session[:mode] = 'users_view'
  haml :user
end

post '/user/add/:user', :ajax => true do
  sql_do('INSERT INTO users (name) VALUES ($1)', [params[:user]])
end

get '/user/show', :ajax => true do
  @users = sql_do('SELECT user_id, name, is_admin FROM users').values
  haml :user_show
end

post '/user/del/:id', :ajax => true do
  sql_do('DELETE FROM users WHERE user_id=$1', [params[:id]])
end

post '/user/promote/:id', :ajax => true do
  sql_do('UPDATE users SET is_admin=TRUE WHERE user_id=$1', [params[:id]])
end

post '/user/demote/:id', :ajax => true do
  sql_do('UPDATE users SET is_admin=FALSE WHERE user_id=$1', [params[:id]])
end
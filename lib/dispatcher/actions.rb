get '/actions/show_form', :ajax => true do
  haml :actions_add
end

post '/actions/add', :ajax => true do
  order = sql_do('SELECT count(ordering) FROM actions WHERE task_id=$1 AND user_id=$2',
    [params[:task_id], session[:user_id]]).values[0][0].to_i + 1
  sql_do('INSERT INTO actions (task_id, body, ordering, user_id) VALUES ($1, $2, $3, $4)',
    [params[:task_id], params[:body], order, session[:user_id]])
end

post '/actions/del/:id', :ajax => true do
  sql_do('DELETE FROM actions WHERE action_id=$1 AND user_id=$2', [params[:id], session[:user_id]])
end

post '/actions/done/:id', :ajax => true do
  sql_do('UPDATE actions SET is_done=true WHERE action_id=$1 AND user_id=$2', [params[:id], session[:user_id]])
end

post '/actions/undone/:id', :ajax => true do
  sql_do('UPDATE actions SET is_done=false WHERE action_id=$1 AND user_id=$2', [params[:id], session[:user_id]])
end

post '/actions/update/:id', :ajax => true do
  sql_do('UPDATE actions SET body=$2 WHERE action_id=$1 AND user_id=$3', [params[:id], params[:body], session[:user_id]])
end
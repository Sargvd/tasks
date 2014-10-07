def parse_tags(body)
  return [body, []] unless body.count('#') > 0
  tags = body.split('#')[1..-1].map {|line| line.split(' ')[0]}
  body.gsub! /#\S+ ?/, ''
  [body, tags]
end

def parse_prio(body)
  return [body, 'medium'] unless body.count('^') > 0
  prio = body.split('^')[1][0].to_i
  #we have to check for to_i exception here
  if [1,2,3].include? prio
    body.gsub! /\^. ?/, ''
  else
    prio = 2
  end
  [body, {1 => 'high', 2 => 'medium', 3 => 'low'}[prio]]
end

def extract_tags(project_id)
  #We don't want to show tags from tasks marked as Archived
  arch_task_ids = sql_do('SELECT t.task_id as id FROM tasks t
        JOIN views v ON t.task_id=v.task_id
        JOIN projects p on p.project_id=t.project_id
        WHERE v.name=\'Done\' AND t.project_id=$1',
      [project_id]).values.flatten || []
  tags = sql_do('SELECT DISTINCT(v.name) FROM views v JOIN tasks t ON v.task_id=t.task_id WHERE t.project_id=$1 AND NOT v.task_id=ANY($2)',
                [project_id, "{#{arch_task_ids.join ','}}"]).values.flatten
  tags = %w(Done).concat tags if arch_task_ids.size > 0
  tags||= []
  %w(Active).concat tags
end

post '/tasks/add', :ajax => true do
  # "Test ^1 #tag1 #tag2 ast" => "Test ast" [tag1, tag2, priority: 1]
  body, tags = parse_tags params[:task]
  body, priority = parse_prio body

  MyConn.instance.conn.transaction do |conn|
    task_id = conn.exec('SELECT nextval(\'tasks_id_seq\')').values[0][0]
    conn.exec('INSERT INTO tasks (user_id, name, project_id, priority, task_id) VALUES ($1, $2, $3, $4, $5)',
               [session[:user_id], body, session[:project_tab], priority, task_id])
    tags.each do |view|
      conn.exec('INSERT INTO views (name, task_id, user_id) VALUES ($1, $2, $3)',
          [view, task_id, session[:user_id]])
    end
  end
end

post '/tasks/show/:id', :ajax => true do
  task = sql_do('SELECT task_id, name, priority FROM tasks WHERE task_id=$1 AND user_id=$2 ORDER BY priority, task_id',
      [params[:id], session[:user_id]]).values[0]
  actions = sql_do('SELECT action_id, body, is_done, action_tag FROM actions
    WHERE task_id=$1 AND user_id=$2 ORDER BY ordering', [params[:id], session[:user_id]]).values || []
  tags = sql_do('SELECT id, name FROM views WHERE task_id=$1 AND user_id=$2', [params[:id], session[:user_id]]).values || []
  task.concat [actions, tags]
  haml :task_block, :locals => {:task => task, :tag_active => session[:tag_active]}
end

get '/tasks/show', :ajax => true do
  tag_active = 'Active' unless session.has_key? :tag_active
  tag_active = session[:tag_active]
  uid = session[:user_id]
  pid = session[:project_tab]

  tasks_done_ids = sql_do('SELECT t.task_id FROM tasks t
    JOIN views v ON t.task_id=v.task_id
    WHERE v.name=\'Done\' AND t.user_id=$1 AND t.project_id=$2',
  [uid, pid]).values.flatten

  case session[:tag_active]
    when 'Done'
      tasks = sql_do('SELECT task_id, name, priority FROM tasks WHERE task_id=ANY($1) AND user_id=$2 AND project_id=$3',
                      ["{#{tasks_done_ids.join ','}}", uid, pid]).values
    when 'Active'
      tasks = sql_do('SELECT task_id, name, priority FROM tasks WHERE user_id=$1 AND project_id=$2 AND NOT task_id=ANY($3)',
                      [uid,pid,"{#{tasks_done_ids.join ','}}"]).values
    else
      tasks = sql_do('SELECT t.task_id, t.name, t.priority FROM tasks t
                        JOIN views v ON t.task_id=v.task_id
                        WHERE v.name=$1 AND NOT t.task_id=ANY($2) AND t.user_id=$3 AND t.project_id=$4',
                      [tag_active, "{#{tasks_done_ids.join ','}}", uid, pid]).values
  end

  tasks.map! do |id, n, p|
    actions = sql_do('SELECT action_id, body, is_done, action_tag FROM actions
      WHERE task_id=$1 AND user_id=$2 ORDER BY ordering', [id, session[:user_id]]).values || []
    tags = sql_do('SELECT id, name FROM views WHERE task_id=$1 AND user_id=$2', [id, session[:user_id]]).values || []
    [id, n, p, actions, tags]
  end

  haml :tasks_show, :locals => {:tasks => tasks, :tag_active => tag_active}
end

post '/tasks/del/:id', :ajax => true do
  MyConn.instance.conn.transaction do |conn|
    conn.exec('DELETE FROM actions WHERE task_id=$1 AND user_id=$2', [params[:id], session[:user_id]])
    conn.exec('DELETE FROM tasks WHERE task_id=$1 AND user_id=$2', [params[:id], session[:user_id]])
    conn.exec('DELETE FROM views WHERE task_id=$1 AND user_id=$2', [params[:id], session[:user_id]])
  end
end

post '/tasks/inline_edit/:id', :ajax => true do
  @rel = params[:id]
  haml :tasks_inline_edit
end

post '/tasks/save/:id', :ajax => true do
  body, tags = parse_tags params[:body]
  MyConn.instance.conn.transaction do |conn|
    conn.exec('UPDATE tasks SET name=$1 WHERE task_id=$2 AND user_id=$3 AND project_id=$4',
             [body, params[:id], session[:user_id], session[:project_tab]])
    tags.each do |tag|
      conn.exec('INSERT INTO views (name, user_id, task_id) VALUES ($1, $2, $3)',
              [tag, session[:user_id], params[:id]])
    end
  end
  sql_do('UPDATE tasks SET name=$1 WHERE task_id=$2 AND user_id=$3 AND project_id=$4',
         [body, params[:id], session[:user_id], session[:project_tab]])
end

post '/tasks/update_priority/:id', :ajax => true do
  new_priority = [nil, 'high', 'medium', 'low'][params[:priority].to_i]
  sql_do('UPDATE tasks SET priority=$1 WHERE task_id=$2', [new_priority, params[:id]])
end

post '/tasks/done/:id', :ajax => true do
  sql_do('INSERT INTO views (name, task_id, user_id) VALUES (\'Done\', $1, $2)',
          [params[:id], session[:user_id]])
end

post '/tasks/undone/:id', :ajax => true do
  sql_do('DELETE FROM views WHERE task_id=$1 AND user_id=$2 AND name=\'Done\'',
          [params[:id], session[:user_id]])
end

post '/tags/del/:id', :ajax => true do
  sql_do('DELETE FROM views WHERE id=$1 AND user_id=$2', [params[:id], session[:user_id]])
end

post '/tags/select/:name', :ajax => true do
  session[:tag_active] = params[:name]
end

post '/tags/add', :ajax => true do
  params[:tag].to_a.each do |tag|
    sql_do('INSERT INTO views (user_id, task_id, name) VALUES ($1, $2, $3)',
         [session[:user_id], params[:task_id], tag])
  end
end

post '/tags/show', :ajax => true do
  tasks_num = sql_do('SELECT count(task_id) FROM tasks WHERE user_id=$1 AND project_id=$2',
                         [session[:user_id], session[:project_tab]]).values.flatten.first.to_i

  tasks_done_ids = sql_do('SELECT t.task_id FROM tasks t
    JOIN views v ON t.task_id=v.task_id
    WHERE v.name=\'Done\' AND t.user_id=$1 AND t.project_id=$2',
    [session[:user_id], session[:project_tab]]).values.flatten

  active_num = tasks_num - tasks_done_ids.size
  tags = []<<['Active', active_num]
  tags<<['Done', tasks_done_ids.size] if tasks_done_ids.size > 0

  custom_tags = sql_do('SELECT v.name, count(v.name) FROM views v
    JOIN tasks t on t.task_id=v.task_id
    WHERE v.user_id=$1 AND t.project_id=$2 AND NOT t.task_id=ANY($3) GROUP BY v.name',
    [session[:user_id], session[:project_tab], "{#{tasks_done_ids.join ','}}"]).values

  tags.concat custom_tags
  haml :tags, :locals => {:tags => tags, :tag_active => session[:tag_active]}
end
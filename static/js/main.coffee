#TODO: input validation! Adding empty delegate causes infinite loop

$(document).ready ->
  $.valHooks.textarea = {get: (e) -> e.value.replace /\r?\n/g, "\r\n"}
  init()

logout = ->
  navigator.id.logout()

init = ->
  #we have to handle 403 issued by AJAX calls and close the session for the client
  $.ajaxSetup {
    error: (x, _, error) ->
      window.location = '/error/not_authorized' if x.status == 403
  }

  #disable text selection for entire document to prevent messing up on doubleclicks/shift+clicks
  # have to handle use cases seperatly though, because it's quite ugly to prevent user from C/P his tasks
  $(document).on 'selectstart', false

  user = null
  $.ajax
    url: '/auth/get_mail'
    async: false
    success: (d) -> user = d
  navigator.id.watch
    loggedInUser: user
    onlogin: ->
      window.location.replace '/auth/login'
    onlogout: ->
      $.get '/auth/logout', -> window.location.reload()

  #Setup navigation bar & tabs

  bar_update()

  $('#navbar').delegate '.select_tab', 'click', (event) ->
    event.preventDefault()
    console.log $(this)
    $.post "/bar/tab/#{$(this).attr 'rel'}", ->
      bar_update()
      tasks_update()
      tags_update()

  $('#navbar').delegate '.add_project', 'click', ->
    bootbox.prompt 'How it should be named?', (name) ->
      $.post "/projects/add/#{name}", -> bar_update() unless name == null

  $('#navbar').delegate '.del_project', 'click', ->
    id = $(this).attr 'rel'
    $.get "/projects/is_empty/#{id}", ->
      projects_del id
    .error ->
      bootbox.confirm 'Are you sure?', (r) ->
        projects_del id if r

  #Show tags
  tags_update()

  #Handling selecting & deleting tags
  $('#tasks').delegate '.del_tag', 'click', ->
    task_el = $(this).closest 'table'
    task_id = task_el.attr 'rel'
    $.post "/tags/del/#{$(this).attr 'rel'}", ->
      tags_update()
      task_update(task_el, task_id)
  $('#tags').delegate '.tag', 'click', (event) ->
    event.preventDefault()
    $.post "/tags/select/#{$(this).attr 'rel'}", ->
      tags_update()
      tasks_update()
  $('#tasks').delegate '.tag_add', 'click', ->
    me = $(this)
    task_el = me.closest('table')
    task_id = task_el.attr 'rel'
    div = me.closest 'div'
    div.empty().append(me).append("
      <input placeholder='Esc to cancel, Enter to add'
        style='height: 20px; margin: 0; padding: 0; padding-left: 5px;'
        type='text'
        id='tag_add_edit'>
      </input>")
    input = div.find('#tag_add_edit')
    input.focus()
    input.bind 'keydown', 'esc', (e)->
      e.preventDefault()
      task_update(task_el, task_id)
    input.bind 'keydown', 'return', (e) ->
      e.preventDefault()
      me = $(this)
      tags = me.val().split(' ')
      if tags.length > 0 then $.post '/tags/add', {task_id: task_id, tag: tags}, ->
        tags_update()
        task_update(task_el, task_id)
      else task_update(task_el, task_id)


  #Handling renaming tabs
  $('#navbar').delegate '.select_tab', 'dblclick', ->
    me = $(this)
    tab_el = me.closest 'b'
    console.log tab_el


  #Set event handlers and defaults for input fields
  tasks_update()
  $('#tasks').delegate '.del', 'click', ->
    $.post "/tasks/del/#{$(this).attr 'rel'}", -> tasks_update()
  $('#tasks').delegate '.task_body', 'dblclick', (event) ->
    event.preventDefault()
    tasks_edit($(this))

  $('.user').on 'click', -> window.location = '/user'

  #handling change priority events (click -> lower prio, shift+click -> increase prio)
  $('#tasks').delegate '.priority', 'click', (event) ->
    new_priority = {2:1, 3:2}[$(this).text()]
    new_priority = {1:2, 2:3}[$(this).text()] if event.shiftKey
    new_priority ||= $(this).text()
    $.post "/tasks/update_priority/#{$(this).attr 'rel'}", {priority: new_priority}, -> tasks_update()

  #handling marking task as 'done'
  $('#tasks').delegate '.done', 'click', (event) ->
    unless event.shiftKey
      $.post "/tasks/done/#{$(this).attr 'rel'}", ->
        tags_update()
        tasks_update()
    else
      $.post "/tasks/del/#{$(this).attr 'rel'}", -> tasks_update()

  #handling action-related events
  $('#tasks').delegate '.action_add', 'click', ->
    me = $(this)
    td = me.closest 'td'
    task_el = me.closest 'table'
    task_id = task_el.attr 'rel'
    td.empty().append("<textarea
      id='action_add_edit'
      placeholder='Esc to cancel, Shift+Enter to add'
      style='width: 100%; margin: 2px'
    </textarea>")
    input = td.find('#action_add_edit')
    input.width '95%'
    input.autosize {append: "\n"}
    input.focus()
    input.bind 'keydown', 'esc', (e) ->
      e.preventDefault()
      task_update(task_el, task_id)
    input.bind 'keydown', 'shift+return', (e) ->
      e.preventDefault()
      body = input.val().replace /\n/g, '<br>'
      $.post '/actions/add', {body: body, task_id: task_id}, -> task_update(task_el, task_id)

  $('#tasks').delegate '.action_done', 'click', ->
    el = $(this)
    $.post "/actions/done/#{$(this).attr 'rel'}", ->
      task_block_el = el.closest 'table'
      task_id = task_block_el.attr 'rel'
      task_update(task_block_el, task_id)

  $('#tasks').delegate '.action_undone', 'click', ->
    el = $(this)
    $.post "/actions/undone/#{$(this).attr 'rel'}", ->
      task_block_el = el.closest 'table'
      task_id = task_block_el.attr 'rel'
      task_update(task_block_el, task_id)

  $('#tasks').delegate '.action_del', 'click', ->
    el = $(this)
    $.post "/actions/del/#{$(this).attr 'rel'}", ->
      task_block_el = el.closest 'table'
      task_id = task_block_el.attr 'rel'
      task_update(task_block_el, task_id)


  #Double click action body => inline edit form
  $('#tasks').delegate '.action_body', 'dblclick', (event) ->
    return false if $('#action_inline_edit').length
    task_el = $(this).closest 'table'
    task_id = task_el.attr 'rel'
    action_id = $(this).closest('tr').attr 'rel'
    td = $(this).closest 'td'
    inh_height = td.height()
    body = $(this).find('span.body').text().trim()
    td.empty().append "<textarea
       id='action_inline_edit'
       style='width: 95%; margin: 2px'
     </textarea>"
    input = td.find '#action_inline_edit'
    input.autosize {append: "\n"}
    input.height inh_height
    input.focus().val(' ').val body
    $('#action_inline_edit').off().bind 'keydown', 'esc', (event) ->
      event.preventDefault()
      task_update(task_el, task_id)
    $('#action_inline_edit').bind 'keydown', 'shift+return', (event) ->
      event.preventDefault()
      $.post "/actions/update/#{action_id}", {body: input.val()}, ->
        task_update(task_el, task_id)

tasks_add = ->
  $.post '/tasks/add', {task: $('#tasks_add_task').val().replace(/\n/g,"<br>")}, ->
    tasks_update()
    $('#tasks_add_task').val ''

tasks_update = ->
  $.get '/tasks/show', (d) ->
    $('#tasks').html d
    $('#tasks_add_task').autosize({append: "\n"})
    $('#tasks_add_task').bind 'keydown', 'shift+return', (event) ->
      event.preventDefault()
      tasks_add()
    add_action_input = $('#tasks').find('.add_action')
    add_action_input.autosize({append: "\n"})
    add_action_input.height '20px'
    add_action_input.bind 'keydown', 'shift+return', (event) ->
      event.preventDefault()
      me = $(this)
      task_block_el = me.closest 'table'
      task_id = task_block_el.attr 'rel'
      action_body = me.val()
      $.post '/actions/add', {body: action_body, task_id: me.attr 'rel'}, ->
        task_update(task_block_el, task_id)
        me.val ''

tasks_edit = (task) ->
  body_text = task.children('b').text().replace(/<br>/g, "\n").trim()
  body_width = task.width() - 15
  body_height = task.height()
  task_id = task.attr 'rel'
  task_block = $("#tasks table[rel='#{task_id}']")
  $('#tasks_inline_edit').replaceWith($('#tasks_inline_edit').val()) if $('#tasks_inline_edit')
  $.post "/tasks/inline_edit/#{task_id}", (d) ->
    task.html d
    $('#tasks_inline_edit').autosize({append: "\n"}).width(body_width).height(body_height)
    $('#tasks_inline_edit').bind 'keydown', 'shift+return', (event) -> event.preventDefault(); tasks_edit_save($(this).attr 'rel')
    $('#tasks_inline_edit').bind 'keydown', 'esc', (event) ->
      event.preventDefault()
      task_update(task_block, task_id)
    #A hack to get the caret to the EOF
    $('#tasks_inline_edit').focus().val(' ').val body_text

tasks_edit_save = (entry_number) ->
  $.post "/tasks/save/#{entry_number}", {body: $('#tasks_inline_edit').val().replace(/\n/g,"<br>")}, ->
    #it's possible that we added a tag, have to redraw all tasks
#    tasks_update()
    task_update($("#tasks table[rel=#{entry_number}]"), entry_number)
    tags_update()

bar_update = ->
  $.get '/bar', (d) ->
    $('#navbar').html d
    $('.logout').on 'click', -> logout()
    $('.user').on 'click', -> window.location = '/user'
    #Search field
    $('#navbar').find('.search-query').bind 'keydown', 'return', (event) ->
      event.preventDefault()
      mid = $(this).val()
      tag = $('#tasks').find("span[rel=\"#{mid}\"]")
      unless tag.length == 0
        $(window).scrollTop tag.offset().top - 100
        tag.effect 'pulsate', 2000
    $('#navbar').find('.search-query').bind 'keydown', 'esc', (event) ->
      event.preventDefault()
      $(this).val ''

projects_del = (id) ->
  $.post "/projects/del/#{id}", ->
    $.get '/projects/reset_id', ->
      bar_update()
      tags_update()
      tasks_update()

task_update = (block, task_id) ->
  $.post "/tasks/show/#{task_id}", (d) ->
    block.html d

tags_update = ->
  $.post '/tags/show', (d) -> $('#tags').html d
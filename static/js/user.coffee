$(document).ready ->
  #we have to handle 403 issued by AJAX calls and close the session for the client
  $.ajaxSetup {
    error: (x, status, error) ->
      window.location = '/error/not_authorized' if x.status == 403
  }

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

  $('#alert').hide()

  $(document).delegate '.admin', 'click', ->
    action = 'promote'
    action = 'demote' if $(this).hasClass('is_admin')
    $.post "/user/#{action}/#{$(this).attr 'rel'}", ->
      user_fire_alert 'success', "User #{action}d."
      user_update()

  $.get '/bar', (d) ->
    $('#navbar').html d
    $('.logout').on 'click', -> logout()
    $('.task').on 'click', -> window.location = '/'

  user_update()
  $('#user').delegate '.del', 'click', ->
    $.post "/user/del/#{$(this).attr 'rel'}", ->
      user_fire_alert 'success', "User removed."
      user_update()


  $('#user_add').bind 'keydown', 'return', (event) ->
    event.preventDefault()
    user = $(this).val()
    $.post "/user/add/#{user}", ->
      user_fire_alert 'success', "User #{user} succesfully added."
      user_update()
      $('#user_add').val ''

user_update = ->
  $.get '/user/show', (d) -> $('#user').html d

user_fire_alert = (type, message) ->
  $('#alert').removeClass()
  $('#alert').addClass "alert alert-#{type}"
  $('#alert').html message
  $('#alert').show 'highlight'
  window.setTimeout user_clear_alert, 3000


user_clear_alert = ->
  $('#alert').hide 'highlight'
  $('#alert').removeClass()

logout = ->
  navigator.id.logout()
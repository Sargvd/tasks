#TODO: autoauth with empty login on first load

$(document).ready ->
  $('#login').bind 'keydown', 'return', (e) ->
    e.preventDefault()
    doLogin()

  $('.login').on 'click', (event) ->
    event.preventDefault()
    doLogin()

  user = null
  $.ajax
    url: '/auth/get_mail'
    async: false
    success: (d) -> user = d
  console.log user
  navigator.id.watch
    loggedInUser: user
    onlogin: (assertion) ->
      return false if $('#login').val() == ''
      $.post('/auth/auth', {assertion: assertion},
        ->
          $('#input-state').removeClass 'error' if $("#input-state").hasClass 'error'
          window.location = '/'
      ).error (d) ->
        $('#input-state').addClass 'error' unless $("#input-state").hasClass 'error'
        fire_alert 'error', d.responseText
    onlogout: ->


doLogin = ->
  $.post('/auth/check', {user: $('#login').val()},
    ->
      navigator.id.request()
      $('#input-state').removeClass 'error' if $("#input-state").hasClass 'error'
  )
  .error (d) ->
    $('#input-state').effect 'shake', {direction: 'up', times: 3}, 300
    $('#input-state').addClass 'error' unless $("#input-state").hasClass 'error'
    fire_alert 'error', d.responseText

fire_alert = (type, message) ->
  $('#alert').removeClass()
  $('#alert').addClass "alert alert-#{type}"
  $('#alert').html message
  $('#alert').show 'highlight'
  window.setTimeout clear_alert, 5000


clear_alert = ->
  $('#alert').html ''
  $('#alert').hide 'highlight'
  $('#alert').removeClass()

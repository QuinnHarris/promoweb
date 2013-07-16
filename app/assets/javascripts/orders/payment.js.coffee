  

$(document).ready ->
  setup_expire = ->
    if $('span#countdown').length
      seconds = $('span#countdown').data('expire')

      apply_expire = ->
        str = ''
        minutes = parseInt(seconds / 60)
        if minutes
          str += minutes + ' minute'
          str += 's' if minutes > 1
          str += '  '
        remain = seconds - minutes * 60
        str += remain + ' seconds'
        $('span#countdown').html(str)
        if seconds == 0
          $('span#countdown').html('EXPIRED')
          $('div#bcmeta').html('')
          clearInterval(countdown)
        seconds--

      apply_expire()
      countdown = setInterval(apply_expire, 1000)
  setup_expire()

  $('a#bitcoinpay').on 'ajax:success', (xhr, data, status) ->
    $('div#bitcoin').html(data)
    setup_expire()
  .on 'ajax:error', (xhr, status, error) ->
    $('div#bitcoin').html('Error: ' + error)

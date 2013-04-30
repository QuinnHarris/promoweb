$(document).ready ->
  set = $('form[method="post"]').not('.noauto')
  set.submit ->
    $(window).unbind 'beforeunload'

  set.one 'change', () ->
    $(window).bind 'beforeunload', () =>
      $.ajax(
        async: false,
        type: 'POST',
        url: this.action,
        data: $(this).serialize()+'&ajax=true'
      )
      null

  $('input.futuredate').datepicker(
    dateFormat: 'yy-mm-dd'
    minDate: 1
    maxDate: 365
    changeMonth: true
    constrainInput: true
  )

  $('input.deactivate').change (event) ->
    set = $(this).parent().children('input').not('[type="hidden"]').not(this)
    if this.checked
      set.attr('disabled', 'disabled')
    else
      set.removeAttr('disabled')

  $('input.activate').change (event) ->
    set = $(this).parents('table.form').find('input').not('[type="hidden"]').not(this)
    if this.checked
      set.removeAttr('disabled')
    else
      set.attr('disabled', 'disabled')

  $('form a.add_child').click ->
    assoc = $(this).attr('data-association')
    container = $('#' + assoc)
    content = $(this).attr('data-template')
    regexp = new RegExp('in_dex', 'g')
    new_id = new Date().getTime();

    container.append(content.replace(regexp, new_id))
    $(this).trigger('change')

  $(document).on 'click', 'form a.remove_child', () ->
    if $('.' + $(this).parent().className).length == 1
      false
    $(this).prev('input[type=hidden]')[0].value = '1'
    $(this).parent().hide()
    $(this).trigger('change')
    false

  $('form input.postalcode').keyup () ->
    return false unless this.value.length == 5

    $(this).trigger('change')

    $.ajax
      url: '/orders/location_from_postalcode_ajax'
      dataType: 'json'
      data: { postalcode: this.value }
      context: this
      success: (data) ->
        for k, v of data
          $('#' + this.id.replace('postalcode', k))[0].value = v

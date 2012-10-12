$(document).ready ->
  # Decoration Move
  $('div.decorations')
    .on 'dragstart', 'div.decoration', (event) ->
      event.originalEvent.dataTransfer.setData('text', event.target.id)
      event.originalEvent.dataTransfer.setData('application/x-moz-node', event.target)
      event.originalEvent.dataTransfer.effectAllowed = 'move'

    .on 'dragover', (event) ->
      node = document.getElementById(event.originalEvent.dataTransfer.getData('text'))
      return true unless node
      return true unless $(node).is('.decoration')
      return true if (event.target == node.parentNode or $(event.target).parents().is(node.parentNode))
      return false

    .on 'drop', (event) ->
      id = event.originalEvent.dataTransfer.getData('text')
      node = document.getElementById(id)
      $(event.target).parents().andSelf().filter('.decorations').first().append(node)

      $.ajax(document.URL+"/drop_decoration",
        type: 'POST'
        context: node
        data:
          id: id.split('=')[1]
          group: $(node).parents('.group')[0].id.split('=')[1]).done (html) ->
        $(this).replaceWith(html)

      return false

  $('div.items')
    .on 'dragstart', 'div.item', (event) ->
      event.originalEvent.dataTransfer.effectAllowed = 'all'
      uri = $(this).find('a').not('[rel="nofollow"]')[0].href
      event.originalEvent.dataTransfer.setData("text/uri-list", uri)
      event.originalEvent.dataTransfer.setData('text/plain', uri)
      event.originalEvent.dataTransfer.setData('text', event.target.id)

    .on 'dragover', (event) ->
      node = document.getElementById(event.originalEvent.dataTransfer.getData('text'))
      return false unless node
      return true unless $(node).is('.item')
      return true if (event.target == node.parentNode or $(event.target).parents().is(node.parentNode))
      event.originalEvent.dataTransfer.effectAllowed = 'move'
      #    return $(event.target).parents('div.decorations')[0] == this
      return false;

    .on 'drop', (event) ->
      if id = event.originalEvent.dataTransfer.getData('text')
        node = document.getElementById(id)
        $(event.target).parents().andSelf().filter('.items').first().append(node)

        $.ajax(document.URL+"/drop_artwork",
          type: 'POST'
          context: node
          data:
            id: id.split('=')[1]
            group: $(node).parents('.group')[0].id.split('=')[1]).done (html) ->
          $(this).replaceWith(html)

        return false

      return false


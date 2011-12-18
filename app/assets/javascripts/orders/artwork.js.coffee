$(document).ready ->
  $('div.group div.items div.item').bind 'dragstart', (event) ->
    event.dataTransfer.effectAllowed = 'copyLink'
    uri = $(this).find('a').not('[rel="nofollow"')[0].href
    event.dataTransfer.setData("text/uri-list", uri)
    event.dataTransfer.setData('text/plain', uri)

  $('div.decoration').bind 'dragstart', (event) ->
    event.dataTransfer.setData('text/plain', 'test')

  $('div#artwork-group= div.decorations').bind 'dragover', (event) ->
    event.dataTransfer.effectAllowed = 'move'
    return $(event.target).parents('div.decorations')[0] == this

  $('div.decorations').bind 'drop', (event) ->

  $('div.group').bind 'dragover', (event) ->
    event.dataTransfer.effectAllowed = 'copy'
#    return $(event.target).parents('div.decorations')[0] == this
    return false;

  $('div.group').bind 'drop', (event) ->
    files = e.dataTransfer.files
    return false unless files?

    #filesDone = fileRejected = 0

    workQueue = i for i in [0...(files.length)] when files[i].size < 1048576 * 20
    processingQueue = []
    doneQueue = []

#    pause = () ->
#      setTimeout(process, 200)

    process = () ->
      return if processingQueue.length > 2

      fileIndex = workQueue[0]
      workQueue.splice(0, 1)

      try
        reader = new FileReader()
        reader.index = fileIndex
        reader.onloadend = send
        reader.readAsBinaryString(files[fileIndex])
        processingQueue.push(fileIndex)
      catch err
        alert("Read Failed")

      process() if workQueue.length > 0

    send = (e) ->
      fileIndex = (if e.srcElement? then e.srcElement else e.target).index
      file = files[fileIndex]

      xhr = new XMLHttpRequest()
      upload = xhr.upload

      start_time = new Date().getTime()
      upload.index = fileIndex
      upload.file = file
      upload.downloadStartTime = start_time
      upload.currentStart = start_time
      upload.currentProgress = 0
      upload.startData = 0
      upload.addEventListener("progress", progress, false)

#      xhr.onload = () ->
#        if xhr.responseText
          # Finish

          #processingQueue

      sendMultipartData(xhr, e.target.result,
        paramname: 'artwork[art]',
        filename: file.name,
        data: ajax: true)

    event.preventDefault()
    return false

#  $('div.group').filedrop(
#    paramname: 'artwork[art]'
#    maxfiles: 25,
#    maxfilesize: 20,
#    data: ajax: true
#  )
#

sendMultipartData = (xhr, filedata, opts) ->
  dashdash = '--'
  crlf = '\r\n'

  boundary = '------multipartformboundary' + (new Date).getTime()

  builder = ''

  if opts.data
    for key, val of opts.data
      builder += dashdash
      builder += boundary
      builder += crlf
      builder += 'Content-Disposition: form-data; name="' + decodeURI(key) + '"';
      builder += crlf
      builder += crlf
      builder += decodeURI(val)
      builder += crlf

  builder += dashdash
  builder += boundary
  builder += crlf
  builder += 'Content-Disposition: form-data; name="' + opts.paramname + '"'
  builder += '; filename="' + opts.filename + '"'
  builder += crlf

  builder += 'Content-Type: ' + opts.mime
  builder += crlf
  builder += crlf

  builder += filedata
  builder += crlf

  builder += dashdash
  builder += boundary
  builder += dashdash
  builder += crlf

  xhr.open("POST", '', true)
  xhr.sendRequestHeader('content-type', 'multipart/form-data; boundary=' + boundary)
  xml.sendAsBinary(builder)

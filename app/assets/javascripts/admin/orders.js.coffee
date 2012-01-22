displayMoney = (val) ->
  digits = (if (val % (multiplier / 100)) then 3 else 2)
  number = (val / multiplier).toFixed(digits)
  x = number.split(".")
  whole = x[0]
  decimal = x[1]
  rgx = /(\d+)(\d{3})/
  while rgx.test(whole)
    whole = whole.replace(rgx, "$1" + "," + "$2")
  "$" + whole + "." + decimal

parseMoney = (val) ->
  return null  if val == ""
  parseInt Math.round(parseFloat(val) * multiplier)

#roundToCent = (val) ->
#  Math.round(val * 100.0 / multiplier) * (multiplier / 100.0)

window.merge_listing = (list) ->
  window.price_listing = $.extend(window.price_listing, list)

get_listing = (id) ->
  window.price_listing[id]

profit_margin_calculate = (node, price, cost) ->
  str = ((price - cost) / multiplier).toFixed(2)
  inputs = $('.profit input', node)
  if inputs.length == 1
    inputs.val(str)
  else
    $('.profit', node).html(displayMoney(price - cost))

  str = (if (price == 0) then "" else ((price - cost) / price * 100.0).toFixed(2))
  inputs = $('.margin input', node)
  if inputs.length == 1
    inputs.val(str)
  else
    $('.margin', node).html(str)

order_item_quantity = (node) ->
  sum = 0
  for inp in $('.shipset', node)
    sum += parseInt(inp.value)
  sum

order_item_row_vals = (tr, update) ->
  table_mapping =
    1: 'unit_price'
    2: 'fixed_price'
    4: 'unit_cost'
    5: 'fixed_cost'

  result = {
    unit_price: 0
    fixed_price: 0
    unit_cost: 0
    fixed_cost: 0 }

  for input in $('input.money', tr)
    val = parseMoney(input.value)
#    val = 0.0 unless val?

    if update and $(tr).hasClass('defined')
      list = get_listing(input.id)
      if input.defaultValue == ""
        setField input, val = list
        $(input).addClass('predicate')
      $(input).toggleClass('changed', val == list)

    result[table_mapping[input.parentNode.cellIndex]] = val

  return result

order_item_calculate = (table) ->
  tbody = table.getElementsByTagName("tbody")[0]
  tfoot = table.getElementsByTagName("tfoot")[0]
  sum_tr = tfoot.rows[0]
  unit_tr = tfoot.rows[1]
  quantity = order_item_quantity(tbody, true)

  sum = {
    unit_price: 0
    fixed_price: 0
    unit_cost: 0
    fixed_cost: 0 }

  j = 0

  for tr in $('tbody tr', table)
    continue if tr.cells.length < 4
    value = order_item_row_vals(tr, true)

    price = value.unit_price * quantity + value.fixed_price
    tr.cells[3].innerHTML = displayMoney(price)

    cost = value.unit_cost * quantity + value.fixed_cost
    tr.cells[6].innerHTML = displayMoney(cost)

    profit_margin_calculate tr, price, cost

    sum[k] += v for k, v of value


  sum_tr.cells[1].innerHTML = displayMoney(sum.unit_price)
  sum_tr.cells[2].innerHTML = displayMoney(sum.fixed_price)
  price = sum.unit_price * quantity + sum.fixed_price
  sum_tr.cells[3].innerHTML = displayMoney(price)

  sum_tr.cells[4].innerHTML = displayMoney(sum.unit_cost)
  sum_tr.cells[5].innerHTML = displayMoney(sum.fixed_cost)
  cost = sum.unit_cost * quantity + sum.fixed_cost
  sum_tr.cells[6].innerHTML = displayMoney(cost)

  profit_margin_calculate sum_tr, price, cost

  unit_tr.cells[0].innerHTML = "(Total Units: " + quantity + ")  Unit Cost:"
  unit_tr.cells[2].innerHTML = displayMoney(sum.fixed_price / quantity)
  unit_tr.cells[3].innerHTML = displayMoney(price / quantity)
  unit_tr.cells[5].innerHTML = displayMoney(sum.fixed_cost / quantity)
  unit_tr.cells[6].innerHTML = displayMoney(cost / quantity)

  { price: price, cost: cost }

order_entry_calculate = (table, other) ->
  sum = { cost: 0, price: 0 }

  for tr in $('tbody tr', table)
    inputs = $('input', tr)

    price = parseMoney(inputs[1].value)
    price = 0  unless price?

    cost = parseMoney(inputs[2].value)
    cost = 0 unless cost?

    units = parseInt(inputs[3].value)

    total = { price: price * units, cost: cost * units }
    tr.cells[4].innerHTML = displayMoney(total.price)
    tr.cells[5].innerHTML = displayMoney(total.cost)

    profit_margin_calculate tr, total.price, total.cost
    sum[k] += v for k, v of total

  tfoot = table.getElementsByTagName("tfoot")[0]
  grand_tr = tfoot.rows[0]
  if tfoot.rows.length > 1
    sum_tr = tfoot.rows[0]
    grand_tr = tfoot.rows[1]
    sum_tr.cells[2].innerHTML = displayMoney(sum.price)
    sum_tr.cells[3].innerHTML = displayMoney(sum.cost)
    profit_margin_calculate sum_tr, sum.price, sum.cost

  sum[k] += v for k, v of other

  grand_tr.cells[1].innerHTML = displayMoney(sum.price)
  grand_tr.cells[2].innerHTML = displayMoney(sum.cost)

  profit_margin_calculate grand_tr, sum.price, sum.cost

  sum


calculate_all = ->
  total = { cost: 0, price: 0 }

  for purchase in $('.invoice .purchase')
    sum = { cost: 0, price: 0 }

    for table in $('.item table', purchase)
      ret = order_item_calculate(table)
      sum[k] += v for k, v of ret

    for table in $('.general table', purchase)
      ret = order_entry_calculate(table, sum)
      sum[k] += v for k, v of ret

    total[k] += v for k, v of sum

  ret = order_entry_calculate($('.invoice > .general table')[0], total)
  total[k] += v for k, v of ret


#  generals = invoice.getElementsByClassName("general")
#  div = generals[generals.length - 1]
#  table = div.getElementsByTagName("table")[0]
#  ret = order_entry_calculate(table, total_price, total_cost)
#  total_price += ret[0]
#  tax_row = $("tax")
#  if tax_row
#    rate = parseFloat(tax_row.cells[1].innerHTML) / 100.0
#    tax_price = roundToCent(total_price * rate)
#    tax_row.cells[2].innerHTML = displayMoney(tax_price)
#    total_row = tax_row.nextSibling.nextSibling
#    total_row.cells[1].innerHTML = displayMoney(total_price + tax_price)

input_press = (event) ->
  kC = $.ui.keyCode
  return true if event.keyCode in [kC.BACKSPACE, kC.TAB, kC.ENTER, kC.ESCAPE, kC.LEFT, kC.UP, kC.RIGHT, kC.DOWN, kC.DELETE, kC.HOME, kC.END, kC.PAGE_UP, kC.PAGE_DOWN, kC.INSERT]
  return true if (event.which >= 48 and event.which <= 57)
  target = $(event.target)
  return true if target.hasClass('negative') and event.which == 45
  return true if target.hasClass('money') and event.which == 46

  event.preventDefault()
  false


#input_press = (event) ->
#  key = event.keyCode
#  keychar = String.fromCharCode(event.charCode)
#  if (key == 0) and (event.target.hasClassName("money") or event.target.hasClassName("num")) and ((("0123456789").indexOf(keychar) < 0) and not (event.target.hasClassName("money") and keychar == ".") and not (event.target.hasClassName("negative") and keychar == "-") and not event.ctrlKey)
#    event.preventDefault()
#    return false
#  if key == Event.KEY_RETURN
#    event.target.blur()
#    event.preventDefault()
#  if key == Event.KEY_ESC
#    nxtSib = event.target.nextSibling
#    return true  if nxtSib and ("hasClassName" of nxtSib) and nxtSib.hasClassName("auto_complete")
#    event.target.setValue event.target.defaultValue
#    event.target.blur()
#  true

parseField = (target, value) ->
  t = $(target)
  return NaN  if t.hasClass("null") and value == ""
  return parseMoney(value)  if t.hasClass("money")
  return parseInt(value)  if t.hasClass("num")
  value

setField = (target, value) ->
  target = $(target)
  return ""  if target.hasClass("null") and (target.hasClass("money") or target.hasClass("num")) and isNaN(value)
  if target.hasClass("money")
    digits = (if (value % (multiplier / 100)) then 3 else 2)
    value = (value / multiplier).toFixed(digits)
  target.val(value)


request_success = (data, textStatus, t) ->
  if typeof(data) == 'string'
    alert "Updating cell value failed with error: " + data
  else
    for key, value of data
      cell = $('#'+key)
      cur = parseField(cell, cell.value)
      setField cell, value  if isNaN(cur)
#    merge_listing data
    calculate_all()
    this.removeClass 'sending'

#request_complete = (request) ->
#  if request.responseText[0] == "{"
#    unless request.responseText == "{}"
#      hash = request.responseText.evalJSON()
#      for key of hash
#        cell = $(key)
#        cur = parseField(cell, cell.value)
#        setField cell, hash[key]  if isNaN(cur)
#      merge_listing hash
#      calculate_all()
#    $(request.request.options.parameters["id"]).removeClassName "sending"
#  else
#    alert "Updating cell value failed with error: " + request.responseText

find_shipping = (target) ->
  if target.hasClassName("shipset")
    elem = target
    while elem and not elem.hasClassName("item")
      elem = elem.parentNode
    shipping = elem.getElementsByClassName("shipping")[0]
    return shipping
  false

input_update = (target) ->
  t = $(target)
  return  if t.hasClass('sending')

  if (ismargin = t.parent().hasClass('margin')) or t.parent().hasClass('profit')
    tr = t.parent().parent()
    quantity = order_item_quantity(tr.parent())
    values = order_item_row_vals(tr, false)

    cost = values.unit_cost * quantity + values.fixed_cost
    if ismargin
      margin = parseFloat(target.value)
      price = cost / (1 - (margin / 100.0))
    else
      profit = Math.round(parseFloat(target.value) * multiplier)
      price = cost + profit

    mult = multiplier / 100
    if values.unit_price? and values.unit_cost?
      price_input = tr[0].cells[1].getElementsByTagName("input")[0]
      setField price_input, Math.round((price - values.fixed_price) / (quantity * mult)) * mult
    else
      price_input = tr[0].cells[2].getElementsByTagName("input")[0]
      setField price_input, Math.round(price / mult) * mult

    input_update price_input
    return

  oldValue = (if t.hasClass('predicate') then NaN else parseField(target, target.defaultValue))
  if target.value == ""
    value = get_listing(target.id)
    unless typeof (value) == "undefined"
      setField target, value
      t.addClass 'predicate'
      target.defaultValue = ""
      newValue = NaN
    else
      if not t.hasClass('null') and (t.hasClass('money') or t.hasClass('num'))
        target.value = target.defaultValue
        return
      newValue = (if t.hasClass('null') then NaN else "")
      target.defaultValue = ""
  else
    newValue = parseField(target, target.value)
    target.defaultValue = setField(target, newValue)
    t.removeClass 'predicate'
  return calculate_all()  if String(newValue) == String(oldValue)
  t.addClass 'sending'

#  shipping = find_shipping(target)
#  shipping.innerHTML = shipping_pending  if shipping

  $.ajax("/admin/orders/set",
    type: 'POST'
    data:
      id: target.id
      newValue: newValue
      oldValue: oldValue
    context: t
    success: request_success)

input_change = (event) ->
  nxtSib = event.target.nextSibling
  return  if nxtSib and ("hasClassName" of nxtSib) and nxtSib.hasClassName("auto_complete") and Element.getStyle(nxtSib, "display") != "none"
  input_update event.target

autocomplete_change = (target, selectedElement) ->
  input_update target

input_blur = (event) ->
  input_update event.target

entry_insert = (request, id, pos) ->
  table = $(id)
  tbody = table.getElementsByTagName("tbody")[0]
  tr = tbody.insertRow((if pos then 3 else tbody.rows.length))
  tr.innerHTML = request.responseText
#  setup_events tr
  calculate_all()

entry_remove = (request, id) ->
  if request.status == 200 and request.responseText == ""
    tr = $(id).parentNode.parentNode
    tbody = tr.parentNode
    tbody.removeChild tr
    calculate_all()

# REMOVE
#setup_events = (obj) ->
#  inputs = obj.getElementsByTagName("input")
#  j = 0
#
#  while j < inputs.length
#    input = inputs[j]
#    continue  if input.type != "text" or input.hasClassName("ignore")
#    Event.observe input, "keypress", input_press
#    Event.observe input, "change", input_change
#    Event.observe input, "blur", input_blur
#    nxtSib = input.nextSibling
#    new Ajax.Autocompleter(input, nxtSib, "/admin/orders/auto_complete_generic", afterUpdateElement: autocomplete_change)  if nxtSib and ("hasClassName" of nxtSib) and nxtSib.hasClassName("auto_complete")
#    j++
#  inputs = obj.getElementsByTagName("textarea")
#  j = 0
#
#  while j < inputs.length
#    input = inputs[j]
#    Event.observe input, "change", input_change
#    Event.observe input, "blur", input_blur
#    j++


variant_change = (target) ->
  ul = $("variants")
  quantity = order_item_quantity(ul)
  return  unless confirm("Set " + quantity + " units for " + target.text + " only")
  $A(ul.getElementsByClassName("shipset")).each (inp) ->
    inp.value = "0"

  imprint = $A(ul.getElementsByClassName("imprint")).inject([], (acc, inp) ->
    value = inp.value
    inp.value = ""
    (if value.empty() then acc else acc.compact().concat([ value ]))
  ).join(", ")
  quant_node = target.parentNode.getElementsByClassName("shipset")[0]
  oldValue = parseInt(quant_node.value)
  quant_node.value = quantity
  target.parentNode.getElementsByClassName("imprint")[0].value = imprint
  quant_node.addClassName "sending"
  new Ajax.Request("/admin/orders/variant_change",
    parameters:
      id: quant_node.id
      oldValue: oldValue
      newValue: quantity
      imprint: imprint

    onComplete: request_complete
  )

shipping_change = (target) ->
  target.addClassName "sending"
  new Ajax.Request("/admin/orders/shipping_set",
    parameters:
      item_id: target.id
      value: target.value

    onComplete: request_complete
  )

get_shipping = (s) ->
  table = s.parentNode.parentNode.parentNode
  new Ajax.Updater(s, "/admin/orders/shipping_get?item_id=" + table.id.split("-")[1],
    asynchronous: true
    evalScripts: true
  )
get_all_shipping = ->
  shippings = document.getElementsByClassName("shipping")
  i = 0

  while i < shippings.length
    s = shippings[i]
    if s.hasClassName("pending")
      s.innerHTML = shipping_pending
      get_shipping s
    else
      inputs = s.getElementsByTagName("input")
      Event.observe inputs[0], "change", shipping_change  if inputs.length == 1
    i++

show = (name) ->
  elem = $(name)
  if elem.hasClassName("hide")
    elem.removeClassName "hide"
  else
    elem.addClassName "hide"

$(document).ready ->
  $('.invoice').delegate('input[type="text"]',
    keypress: input_press,
    change: input_change,
    blur: input_blur)

  calculate_all()

 # invoice = $('.invoice')
 # if invoice.length > 0
 #   setup_events invoice
 #   calculate_all()
 #   get_all_shipping()

  $(document).delegate '.add', 'ajax:success', (xhr, data, status) ->
    target = $(xhr.target)
    rows = $('tbody tr.defined', target.parents('table:first'))
    node = $('<tr/>')
    if target.hasClass('dec')
      rows = rows.filter('.dec')
      node.addClass('dec')
    rows.last().after(node.html(data))
    calculate_all()

  $(document).delegate '.remove', 'ajax:success', (xhr, data, status) ->
    $(xhr.target).parents('tr:first').remove()
    calculate_all()

multiplier = 1000.0

shipping_pending = "Retrieving Shipping Prices <img src=\"/images/spin30.gif\"/>\""

listing = {}


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
  return NaN  if val == ""
  parseInt Math.round(parseFloat(val) * multiplier)

roundToCent = (val) ->
  Math.round(val * 100.0 / multiplier) * (multiplier / 100.0)

window.merge_listing = (list) ->
  listing = $.extend(listing, list)

get_listing = (id) ->
  listing.get id

profit_margin_calculate = (cells, index, price, cost) ->
  str = ((price - cost) / multiplier).toFixed(2)
  inputs = cells[index].getElementsByTagName("input")
  if inputs.length == 1
    inputs[0].value = str
  else
    cells[index].innerHTML = displayMoney(price - cost)
  str = (if (price == 0) then "" else ((price - cost) / price * 100.0).toFixed(2))
  inputs = cells[index + 1].getElementsByTagName("input")
  if inputs.length == 1
    inputs[0].value = str
  else
    cells[index + 1].innerHTML = str

order_item_quantity = (node) ->
  $A(node.getElementsByClassName("shipset")).inject 0, (acc, inp) ->
    acc + parseInt(inp.value)

order_item_row_vals = (tr, update) ->
  vals = []
  k = 1

  while k < tr.cells.length - 3
    cell = tr.cells[k]
    inputs = cell.getElementsByTagName("input")
    if inputs.length > 0
      input = inputs[0]
      val = parseMoney(input.value)
      val = 0.0  if isNaN(val)
      if update and tr.hasClassName("defined")
        list = get_listing(input.id)
        if input.defaultValue == ""
          setField input, val = list
          input.addClassName "predicate"
        if val == list
          input.removeClassName "changed"
        else
          input.addClassName "changed"
      vals[table_mapping[k]] = val
    else
      vals[table_mapping[k]] = 0.0
    k++
  vals

order_item_calculate = (table) ->
  tbody = table.getElementsByTagName("tbody")[0]
  tfoot = table.getElementsByTagName("tfoot")[0]
  sum_tr = tfoot.rows[0]
  unit_tr = tfoot.rows[1]
  quantity = order_item_quantity(tbody, true)
  sum = [ 0.0, 0.0, 0.0, 0.0 ]
  j = 0

  while j < tbody.rows.length
    tr = tbody.rows[j]
    continue  if tr.cells.length == 1
    vals = order_item_row_vals(tr, true)
    price = vals[0] * quantity + vals[1]
    tr.cells[3].innerHTML = displayMoney(price)
    cost = vals[2] * quantity + vals[3]
    tr.cells[6].innerHTML = displayMoney(cost)
    profit_margin_calculate tr.cells, 7, price, cost
    k = 0

    while k < sum.length
      sum[k] += vals[k]
      k++
    j++
  price = sum[0] * quantity + sum[1]
  cost = sum[2] * quantity + sum[3]
  sum_tr.cells[1].innerHTML = displayMoney(sum[0])
  sum_tr.cells[2].innerHTML = displayMoney(sum[1])
  sum_tr.cells[3].innerHTML = displayMoney(price)
  sum_tr.cells[4].innerHTML = displayMoney(sum[2])
  sum_tr.cells[5].innerHTML = displayMoney(sum[3])
  sum_tr.cells[6].innerHTML = displayMoney(cost)
  profit_margin_calculate sum_tr.cells, 7, price, cost
  unit_tr.cells[0].innerHTML = "(Total Units: " + quantity + ")  Unit Cost:"
  unit_tr.cells[2].innerHTML = displayMoney(sum[1] / quantity)
  unit_tr.cells[3].innerHTML = displayMoney(price / quantity)
  unit_tr.cells[5].innerHTML = displayMoney(sum[3] / quantity)
  unit_tr.cells[6].innerHTML = displayMoney(cost / quantity)
  [ price, cost ]
order_entry_calculate = (table, other_price, other_cost) ->
  price_sum = 0.0
  cost_sum = 0.0
  tbody = table.getElementsByTagName("tbody")[0]
  if tbody
    j = 0

    while j < tbody.rows.length
      tr = tbody.rows[j]
      price = parseMoney(tr.cells[1].getElementsByTagName("input")[0].value)
      price = 0.0  if isNaN(price)
      cost = parseMoney(tr.cells[2].getElementsByTagName("input")[0].value)
      cost = 0.0  if isNaN(cost)
      units = parseInt(tr.cells[3].getElementsByTagName("input")[0].value)
      total_price = price * units
      total_cost = cost * units
      tr.cells[4].innerHTML = displayMoney(total_price)
      tr.cells[5].innerHTML = displayMoney(total_cost)
      profit_margin_calculate tr.cells, 6, total_price, total_cost
      price_sum += total_price
      cost_sum += total_cost
      j++
  tfoot = table.getElementsByTagName("tfoot")[0]
  grand_tr = tfoot.rows[0]
  if tbody
    sum_tr = tfoot.rows[0]
    grand_tr = tfoot.rows[1]
    sum_tr.cells[2].innerHTML = displayMoney(price_sum)
    sum_tr.cells[3].innerHTML = displayMoney(cost_sum)
    profit_margin_calculate sum_tr.cells, 4, price_sum, cost_sum
  grand_tr.cells[1].innerHTML = displayMoney(price_sum + other_price)
  grand_tr.cells[2].innerHTML = displayMoney(cost_sum + other_cost)
  profit_margin_calculate grand_tr.cells, 3, price_sum + other_price, cost_sum + other_cost
  [ price_sum, cost_sum ]

input_press = (event) ->
  key = event.keyCode
  keychar = String.fromCharCode(event.charCode)
  if (key == 0) and (event.target.hasClassName("money") or event.target.hasClassName("num")) and ((("0123456789").indexOf(keychar) < 0) and not (event.target.hasClassName("money") and keychar == ".") and not (event.target.hasClassName("negative") and keychar == "-") and not event.ctrlKey)
    event.preventDefault()
    return false
  if key == Event.KEY_RETURN
    event.target.blur()
    event.preventDefault()
  if key == Event.KEY_ESC
    nxtSib = event.target.nextSibling
    return true  if nxtSib and ("hasClassName" of nxtSib) and nxtSib.hasClassName("auto_complete")
    event.target.setValue event.target.defaultValue
    event.target.blur()
  true

parseField = (target, value) ->
  return NaN  if target.hasClassName("null") and value == ""
  return parseMoney(value)  if target.hasClassName("money")
  return parseInt(value)  if target.hasClassName("num")
  value
setField = (target, value) ->
  return ""  if target.hasClassName("null") and (target.hasClassName("money") or target.hasClassName("num")) and isNaN(value)
  if target.hasClassName("money")
    digits = (if (value % (multiplier / 100)) then 3 else 2)
    return target.value = (value / multiplier).toFixed(digits)
  target.value = value

request_complete = (request) ->
  if request.responseText[0] == "{"
    unless request.responseText == "{}"
      hash = request.responseText.evalJSON()
      for key of hash
        cell = $(key)
        cur = parseField(cell, cell.value)
        setField cell, hash[key]  if isNaN(cur)
      merge_listing hash
      calculate_all()
    $(request.request.options.parameters["id"]).removeClassName "sending"
  else
    alert "Updating cell value failed with error: " + request.responseText

find_shipping = (target) ->
  if target.hasClassName("shipset")
    elem = target
    while elem and not elem.hasClassName("item")
      elem = elem.parentNode
    shipping = elem.getElementsByClassName("shipping")[0]
    return shipping
  false

input_update = (target) ->
  return  if target.hasClassName("sending")
  if target.hasClassName("margin") or target.hasClassName("profit")
    tr = target.parentNode.parentNode
    quantity = order_item_quantity(tr.parentNode)
    vals = order_item_row_vals(tr, false)
    cost = vals[2] * quantity + vals[3]
    fixed = vals[1]
    mult = multiplier / 100
    if target.hasClassName("margin")
      margin = parseFloat(target.value)
      price = cost / (1 - (margin / 100.0))
    else
      profit = Math.round(parseFloat(target.value) * multiplier)
      price = cost + profit
    if vals[0] * quantity > vals[1]
      price_input = tr.cells[1].getElementsByTagName("input")[0]
      setField price_input, Math.round((price - fixed) / (quantity * mult)) * mult
    else
      price_input = tr.cells[2].getElementsByTagName("input")[0]
      setField price_input, Math.round(price / mult) * mult
    input_update price_input
    return
  oldValue = (if target.hasClassName("predicate") then NaN else parseField(target, target.defaultValue))
  if target.value == ""
    value = get_listing(target.id)
    unless typeof (value) == "undefined"
      setField target, value
      target.addClassName "predicate"
      target.defaultValue = ""
      newValue = NaN
    else
      if not target.hasClassName("null") and (target.hasClassName("money") or target.hasClassName("num"))
        target.value = target.defaultValue
        return
      newValue = (if target.hasClassName("null") then NaN else "")
      target.defaultValue = ""
  else
    newValue = parseField(target, target.value)
    target.defaultValue = setField(target, newValue)
    target.removeClassName "predicate"
  return calculate_all()  if String(newValue) == String(oldValue)
  target.addClassName "sending"
  shipping = find_shipping(target)
  shipping.innerHTML = shipping_pending  if shipping
  new Ajax.Request("/admin/orders/set",
    parameters:
      id: target.id
      newValue: newValue
      oldValue: oldValue

    onComplete: ((response, json) ->
      request_complete response
      get_shipping shipping  if shipping
    )
  )

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
setup_events = (obj) ->
  inputs = obj.getElementsByTagName("input")
  j = 0

  while j < inputs.length
    input = inputs[j]
    continue  if input.type != "text" or input.hasClassName("ignore")
    Event.observe input, "keypress", input_press
    Event.observe input, "change", input_change
    Event.observe input, "blur", input_blur
    nxtSib = input.nextSibling
    new Ajax.Autocompleter(input, nxtSib, "/admin/orders/auto_complete_generic", afterUpdateElement: autocomplete_change)  if nxtSib and ("hasClassName" of nxtSib) and nxtSib.hasClassName("auto_complete")
    j++
  inputs = obj.getElementsByTagName("textarea")
  j = 0

  while j < inputs.length
    input = inputs[j]
    Event.observe input, "change", input_change
    Event.observe input, "blur", input_blur
    j++

calculate_all = ->
  invoice = document.getElementsByClassName("invoice")[0]
  total_price = 0
  total_cost = 0
  purchases = invoice.getElementsByClassName("purchase")
  i = 0

  while i < purchases.length
    purchase_price = 0
    purchase_cost = 0
    divs = purchases[i].getElementsByClassName("item")
    j = 0

    while j < divs.length
      table = divs[j].getElementsByTagName("table")[0]
      ret = order_item_calculate(table)
      purchase_price += ret[0]
      purchase_cost += ret[1]
      j++
    div = purchases[i].getElementsByClassName("general")[0]
    if div
      table = div.getElementsByTagName("table")[0]
      ret = order_entry_calculate(table, purchase_price, purchase_cost)
      purchase_price += ret[0]
      purchase_cost += ret[1]
    total_price += purchase_price
    total_cost += purchase_cost
    i++
  generals = invoice.getElementsByClassName("general")
  div = generals[generals.length - 1]
  table = div.getElementsByTagName("table")[0]
  ret = order_entry_calculate(table, total_price, total_cost)
  total_price += ret[0]
  tax_row = $("tax")
  if tax_row
    rate = parseFloat(tax_row.cells[1].innerHTML) / 100.0
    tax_price = roundToCent(total_price * rate)
    tax_row.cells[2].innerHTML = displayMoney(tax_price)
    total_row = tax_row.nextSibling.nextSibling
    total_row.cells[1].innerHTML = displayMoney(total_price + tax_price)
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

#  document.on_ "ajax:success", ".add", (event, container) ->
#    tbody = container.up("table").down("tbody")
#    insert_row = tbody.rows.length
#    if container.hasClassName("dec")
#      i = 0
#      while i < tbody.rows.length
#        insert_row = i  if tbody.rows[i].hasClassName("dec")
#        i++
#      insert_row++
#    tr = tbody.insertRow(insert_row)
#    tr.addClassName "dec"  if container.hasClassName("dec")
#    tr.innerHTML = event.memo.responseText
#    setup_events tr
#    calculate_all()

#  document.on_ "ajax:success", ".remove", (event, container) ->
#    tr = container.up("tr")
#    tr.parentNode.removeChild tr
#    calculate_all()

multiplier = 1000.0

shipping_pending = "Retrieving Shipping Prices <img src=\"/images/spin30.gif\"/>\""

listing = {}

table_mapping =
  1: 0
  2: 1
  4: 2
  5: 3


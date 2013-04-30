multiplier = 1000.0

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

roundToCent = (val) ->
  Math.round(val * 100.0 / multiplier) * (multiplier / 100.0)

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

  for input in $('input.money', tr).slice(0,-2)
    val = parseMoney(input.value)

    if update and $(tr).hasClass('defined')
      list = get_listing(input.id)
      if input.defaultValue == ""
        setField input, val = list
        $(input).addClass('predicate')
      $(input).toggleClass('changed', !(val == list))

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


  if sum_tr = $('tfoot tr.sub', table)[0]
    sum_tr.cells[2].innerHTML = displayMoney(sum.price)
    sum_tr.cells[3].innerHTML = displayMoney(sum.cost)
    profit_margin_calculate sum_tr, sum.price, sum.cost

  sum[k] += v for k, v of other

  grand_tr = $('tfoot tr.grand', table)[0]
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
      sum = order_entry_calculate(table, sum)

    total[k] += v for k, v of sum

  total = order_entry_calculate($('.invoice > .general table')[0], total)

  if tax_row = $('tr#tax')[0]
    rate = parseFloat(tax_row.cells[1].innerHTML) / 100.0
    tax_price = roundToCent(total.price * rate)
    tax_row.cells[2].innerHTML = displayMoney(tax_price)
    total_row = tax_row.nextSibling.nextSibling
    total_row.cells[1].innerHTML = displayMoney(total.price + tax_price)

  return null


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
  return value


request_success = (data, textStatus, t) ->
  if typeof(data) == 'string'
    alert "Updating cell value failed with error: " + data
  else
    merge_listing data
    for key, value of data
      cell = $('#'+key)
      if cell.hasClass('predicate')
        setField cell, value
    this.removeClass 'sending'
    calculate_all()


input_update = (target) ->
  t = $(target)
  return null if t.hasClass('sending')

  if (ismargin = t.parent().hasClass('margin')) or t.parent().hasClass('profit')
    tr = t.parent().parent()
    if unit = tr.parent().hasClass('unit')
      quantity = order_item_quantity(tr.parent())
      values = order_item_row_vals(tr, false)
      cost = values.unit_cost * quantity + values.fixed_cost
      fixed_price = values.fixed_price
    else
      inputs = $('input', tr)
      quantity = parseInt(inputs[3].value)
      cost = parseMoney(inputs[2].value) * quantity
      fixed_price = 0.0

    if ismargin
      margin = parseFloat(target.value)
      price = cost / (1 - (margin / 100.0))
    else
      profit = Math.round(parseFloat(target.value) * multiplier)
      price = cost + profit

    if !unit or values.unit_price > 0
      price_input = tr[0].cells[1].getElementsByTagName("input")[0]
      setField price_input, roundToCent((price - fixed_price) / quantity)
    else
      price_input = tr[0].cells[2].getElementsByTagName("input")[0]
      setField price_input, roundToCent(price)

    input_update price_input
    return null

  oldValue = (if t.hasClass('predicate') then NaN else parseField(target, target.defaultValue))
  if target.value == ""
    value = get_listing(target.id)
    unless typeof (value) == "undefined"
      setField target, value
      t.addClass 'predicate'
      newValue = NaN
    else
      if not t.hasClass('null') and (t.hasClass('money') or t.hasClass('num'))
        target.value = target.defaultValue
        return null

      newValue = (if t.hasClass('null') then NaN else "")
    target.defaultValue = ''
  else
    newValue = parseField(target, target.value)
    target.defaultValue = setField(target, newValue)
    t.removeClass 'predicate'

  return calculate_all()  if String(newValue) == String(oldValue)
  t.addClass 'sending'

  $.ajax("/admin/orders/set",
    type: 'POST'
    data:
      id: target.id
      newValue: newValue
      oldValue: oldValue
    context: t
    success: request_success)

  # Fetch shipping if shipset class (variant quantities)
  if t.hasClass('shipset')
    get_shipping($('td.shipping', t.parents('tbody:first')))

  return null

autocomplete_change = (target, selectedElement) ->
  input_update target


get_shipping = (s) ->
  shipping_pending = 'Retrieving Shipping Prices <img src="/images/spin30.gif">'
  s.html(shipping_pending)
  table = s.parents('table:first')[0]
  s.load('/admin/orders/shipping_get',
         'item_id='+ table.id.split('-')[1])

window.show = (name) ->
  elem = $(name)
  if elem.hasClass("hide")
    elem.removeClass "hide"
  else
    elem.addClass "hide"

apply_code = (code, target) ->
  cellIndex = target.parent()[0].cellIndex
  return unless cellIndex <= 5 # in price or cost column

  code &= 0xDF # UPCASE
  discount = 0.0
  if code >= 65 and code <= 74
    discount = (75 - code) * 0.05
  else if code >= 76 and code <= 89
    discount = (90 - code) * 0.05
  return unless discount > 0.0

  if cellIndex > 2
    input = target
    val = $('input', target.parent().parent()[0].cells[cellIndex-3]).val()
  else
    input = $('input', target.parent().parent()[0].cells[cellIndex+3])
    val = target.val()

  setField input, parseMoney(val) * (1.0-discount)
  input_update input[0]

  calculate_all()
  return


$(document).ready ->
  # Date Picker for shipping
  $('input.shipdate').datepicker(
    dateFormat: 'yy-mm-dd'
    minDate: -5
    maxDate: 365
    changeMonth: true
    constrainInput: true
  )

  invoice = $('.invoice')
  return null if invoice.length == 0
  invoice
    .delegate('input[type="text"].money',
      keypress: (event) ->
        kC = $.ui.keyCode
        return true if event.keyCode in [kC.BACKSPACE, kC.TAB, kC.ESCAPE, kC.LEFT, kC.UP, kC.RIGHT, kC.DOWN, kC.DELETE, kC.HOME, kC.END, kC.PAGE_UP, kC.PAGE_DOWN, kC.INSERT]
        return true if (event.which >= 48 and event.which <= 57)
        target = $(event.target)
        return true if target.hasClass('negative') and event.which == 45
        return true if target.hasClass('money') and event.which == 46
        apply_code(event.which, target)
        return false
    )

    .delegate('input[type="text"]:not(.ignore), textarea',
      keypress: (event) ->
        # Prevent from submitting form if for PO create
        if event.keyCode == $.ui.keyCode.ENTER and event.target.tagName != 'TEXTAREA'
          $(event.target).trigger('change')
          return false
        return true
      change: (event) ->
        nxtSib = event.target.nextSibling
        return null if nxtSib and ("hasClassName" of nxtSib) and nxtSib.hasClassName("auto_complete") and Element.getStyle(nxtSib, "display") != "none"
        input_update event.target
        return null
      blur: (event) ->
        input_update event.target
        return null
    )

    .delegate('td.shipping select',
      change: (event) ->
        $.ajax("/admin/orders/shipping_set",
          type: 'POST'
          data:
            id: event.target.id
            value: event.target.value
          context: $(event.target)
          success: request_success)
    )

    .delegate('dl.variants dd ul li a',
      click: (event) ->
        target = $(event.target)
        root = target.parents('dl.variants')
        quantity = order_item_quantity(root)
        return null unless confirm("Set " + quantity + " units for " + target.text() + " only")

        quantity_inp = $('.shipset', target.parent())
        imprint_inp = $('.imprint', target.parent())
        imprint = []
        for i in $('.imprint', root)
          imprint.push(i.value) if i.value? and i.value != ''
        imprint = imprint.join(', ')
        $('.shipset', root).val(0)
        $('.imprint', root).val('')
        old_quantity = parseInt(quantity_inp.val())
        quantity_inp.val(quantity)
        imprint_inp.val(imprint)

        quantity_inp.addClass('sending')

        $.ajax('/admin/orders/variant_change',
          type: 'POST'
          data:
            id: quantity_inp[0].id
            oldValue: old_quantity
            newValue: quantity
            imprint: imprint
          context: quantity_inp
          success: request_success
        )

        return null
    )

  calculate_all()

  # Get shipping Info
  for ship in $('td.shipping')
    s = $(ship)
    if s.hasClass('pending')
      get_shipping(s)

  $(document).delegate '.add', 'ajax:success', (xhr, data, status) ->
    target = $(xhr.target)
    if target.hasClass('dec')
      rows = $('tbody tr.dec, tbody tr.defined', target.parents('table:first'))
      rows.last().after(data)
    else
      $('tbody', target.parents('table:first')).append(data)
    calculate_all()

  $(document).delegate '.remove', 'ajax:success', (xhr, data, status) ->
    $(xhr.target).parents('tr:first').remove()
    calculate_all()

  return null

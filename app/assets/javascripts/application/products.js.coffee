id_parse = (str) ->
  arr = str.split("-")
  parseInt arr[1]

int_to_money = (val) ->
  negative = val < 0
  val = -val  if negative
  number = (val / 1000).toFixed(2)
  if number.length > 6
    mod = number.length % 3
    output = (if mod > 0 then (number.substring(0, mod)) else "")
    max = Math.floor(number.length / 3)
    i = 0
    while i < max
      if (mod == 0) and (i == 0) or (i == max - 1)
        output += number.substring(mod + 3 * i, mod + 3 * i + 3)
      else
        output += "," + number.substring(mod + 3 * i, mod + 3 * i + 3)
      i++
  else
    output = number
  (if negative then "-" else "") + "$" + output

array_to_range = (array) ->
  [ array.min(), array.max() ]

num_to_str = (num) ->
  if num >= 2000000000
    "Call"
  else if not num and num != 0
    ""
  else
    int_to_money num

range_to_string = (range) ->
  if (range.min or 0) == (range.max or 0)
    return num_to_str(range.min)
  else
    return num_to_str(range.min) + "<br/>to " + num_to_str(range.max)

range_multiply = (range, n) ->
  min: range.min * n
  max: range.max * n

range_add = (a, b) ->
  min: a.min + b.min
  max: a.max + b.max

range_apply = (range, val) ->
  range.min = Math.min(range.min, val)
  range.max = Math.max(range.max, val)
  range

set_layout = ->
  image = $("#prod_img")[0]
  content = $("#content")[0]
  prices = $("#prices")[0]
  return unless prices?
  offset = 0
  for elem in $("#price_calc, #price_list")
    o = elem.offsetWidth + elem.offsetLeft
    offset = o  if o > offset

  prices.style.minWidth = (offset + image.offsetWidth - prices.offsetLeft + 4) + "px"
  bottom = image.offsetTop + image.offsetHeight
  pos = $("#static").offsetTop
  for div in $("div#static div")
    div.style.maxWidth = image.offsetLeft - div.offsetLeft - 20 + "px"  if pos < bottom
    pos += div.offsetHeight

class PricingBase
  constructor: (@data) ->

  _decorationFind: (id) ->
    for dec in @data.decorations
      return dec if dec.id == id

  _decorationPriceFunc: (entry, quantity) ->
    Math.round entry.price_marginal * (1 + entry.price_const * Math.pow(quantity, entry.price_exp))

  _decorationPriceMult: (entry, value, mult) ->
    num = Math.floor((value - 1 - entry.offset) / entry.divisor)
    (if num then (num * mult) else 0)

  _decorationCountLimit: (params, dec) ->
    min = 2147483647
    for e in dec.locations
      if e.id == params.location_id
        return e.limit
      min = e.limit if e.limit < min
    min

  decorationCountLimit: (params) ->
    dec = @_decorationFind(params.technique_id)
    return null  unless dec
    @_decorationCountLimit(params, dec)

  decorationPrice: (params) ->
    dec = @_decorationFind(params.technique_id)
    return NaN  unless dec
    fixed =
      min: 2147483647
      max: 0

    marginal =
      min: 2147483647
      max: 0

    count_limit = @_decorationCountLimit(params, dec)
    for entry in (if dec.entries then dec.entries.reverse() else [])
      break  if params.dec_count and entry.minimum > params.dec_count
      fixed_val = entry.fixed.price_fixed
      marginal_val = @_decorationPriceFunc(entry.fixed, params.quantity)
      unless params.dec_count
        range_apply fixed, fixed_val
        range_apply marginal, marginal_val
      value = (if params.dec_count then params.dec_count else count_limit)
      if value
        fixed_val += @_decorationPriceMult(entry.fixed, value, entry.marginal.price_fixed)
        marginal_val += @_decorationPriceMult(entry.marginal, value, @_decorationPriceFunc(entry.marginal, params.quantity))
        range_apply fixed, fixed_val
        range_apply marginal, marginal_val
      params.dec_count

    fixed: fixed
    marginal: marginal

  _priceSingle: (grp, n) ->
    fixed = NaN
    marginal = NaN
    for brk in grp.breaks
      break if brk.minimum > n
      fixed = brk.fixed
      marginal = brk.marginal

    unless marginal
      ret =
        fixed: 2147483647
        marginal: 2147483647
      return ret
    fixed: 0.0
    marginal: Math.round(fixed / (n * 10.0)) * 10 + Math.round((marginal + grp.constant * Math.pow(n, grp.exp)) / 10.0) * 10

  _priceGroup: (groups, qty) ->
    fixed =
      min: 2147483647
      max: 0

    marginal =
      min: 2147483647
      max: 0

    for group in groups
      prices = @_priceSingle(group, qty)
      range_apply fixed, prices.fixed
      range_apply marginal, prices.marginal

    min: marginal.min + (fixed.min / qty)
    max: marginal.max + (fixed.max / qty)

  _getGroups: (params) ->
    return @data.groups  unless params.variants
    entry for entry in @data.groups when (e for e in entry.variants when e in params.variants).length

  variantPrice: (params) ->
    groups = @_getGroups(params)
    quantity = (if (params.technique_id == 1) then Math.max(@data.minimums[0], params.quantity) else params.quantity)
    @_priceGroup groups, quantity


class window.ProductPricing extends PricingBase
  constructor: (@data) ->
    @params = {}
    @quantity = $("#quantity")
    @unit = $("#unit_value")

    quantity = parseInt($.cookie('quantity'))
    if quantity
      @quantity.val(quantity)
      @params.quantity = quantity

    li = []
    technique_id = parseInt($.cookie('technique'))
    if technique_id
      li = $("#tech-" + technique_id)
      @params.dec_count = parseInt($.cookie('count'))  if li.length
    unless li.length
      li = $("#techniques .sel")
      if li.length
        technique_id = id_parse(li[0].id)
      else
        technique_id = null
    @params.technique_id = technique_id

    if li.length
      @applyTechnique li
      @unit.keypress @changeCount

    @applyPrices()
    @quantity.keypress @changeQuantity

    $("#variants dt a").click @onMouseClrVariant
    $("#variants dd a").click @onMouseSelVariant
    $("#techniques a").click @onMouseTechnique
    $("a.submit").click @orderSubmit

  _selectVariant: (li) ->
    li.parent().children().removeClass('sel')
    li.addClass('sel')

  applyTechnique: (li) ->
    @_selectVariant li
    dec = @_decorationFind(@params.technique_id)
    return  unless dec

    ul = $("#locations")
    dd = ul.parent()
    dt = dd.prev()
    if dec.locations.length > 0
      elems = []
      for loc in dec.locations
        elems.push "<li id=\"dec-" + loc.id + "\"><a href=\"#\"><span>" + loc.display + "</span></a></li>"

      ul.html(elems.join(""))
      dd.show()
      dt.show()
      $("#locations li a").click @onMouseLocation
    else
      dd.hide()
      dt.hide()

    inp = $("#unit_value")
    if inp.length
      @params.dec_count = dec.unit_default  unless @params.dec_count
      dd = inp.parent()
      dt = dd.prev()
      if dec.unit_name and dec.unit_name.length > 0
        dt.html("<span>Number of " + dec.unit_name + "(s):</span>")
        dt.show()
        dd.show()
        inp.value = @params.dec_count  if @params.dec_count
      else
        dt.hide()
        dd.hide()

    $("#dec_desc").html(li.children('span').html())
    if @params.technique_id == 1
      $('#sample').show()
    else
      $('#sample').hide()

  onMouseTechnique: (event) =>
    li = $(event.target).parents('li')
    @params.technique_id = id_parse(li[0].id)
    $.cookie('technique', @params.technique_id)
    @applyTechnique li
    @applyPrices()
    true

  onMouseLocation: (event) =>
    li = $(event.target).parents('li')
    @_selectVariant li
    @params.location_id = id_parse(li[0].id)

  onMouseSelVariant: (event) =>
    li = $(event.target).parents('li')
    @_selectVariant li
    @params.variants = (parseInt(str) for str in li[0].getAttribute("data-variants").split(" "))
    @applyPrices()
    $('#main_imgs').data('cycle.opts').setVariants(@params.variants)


  onMouseClrVariant: (event) =>
    $(event.target).parents('dt').next().children().children().removeClass('sel')
    @params.variants = null
    @applyPrices()
    $('#main_imgs').data('cycle.opts').setVariants(@params.variants)

  _onKeyPress: (event) =>
    kC = $.ui.keyCode
    return true if event.keyCode in [kC.BACKSPACE, kC.TAB, kC.ENTER, kC.ESCAPE, kC.LEFT, kC.UP, kC.RIGHT, kC.DOWN, kC.DELETE, kC.HOME, kC.END, kC.PAGE_UP, kC.PAGE_DOWN, kC.INSERT]
    return true if (event.which >= 48 and event.which <= 57)
    event.preventDefault()
    false

  changeQuantity: (event) =>
    return false unless @_onKeyPress event
    window.setTimeout( () =>
            @params.quantity = parseInt(@quantity.val())
            $.cookie('quantity', @params.quantity)
            @applyPrices()
        , 0)
    true

  changeCount: (event) =>
    return unless @_onKeyPress event
    window.setTimeout( () =>
            count_limit = @decorationCountLimit(@params)
            @params.dec_count = parseInt(@unit.val())
            if @params.dec_count > count_limit
              @params.dec_count = count_limit
              @unit.val(@params.dec_count)
            $.cookie('count', @params.dec_count)
            @applyPrices()
        , 0)
    true

  applyPrices: ->
    dec_price = @decorationPrice(@params)
    if dec_price
      $("#dec_unit_price").html(range_to_string(dec_price.marginal))
      total = range_multiply(dec_price.marginal, @params.quantity)
      $("#dec_total_price").html(range_to_string(total))
      $("#dec_fixed_price").html(range_to_string(dec_price.fixed))
      total = range_add(total, dec_price.fixed)
    else
      total =
        min: 0.0
        max: 0.0
    if total.max == 0.0
      $("#prices .dec").hide()
    else
      $("#prices .dec").show()

    $("#addtoorder")[0].rowSpan = (if (total.max == 0.0) then 2 else 4)
    unit = @variantPrice(@params)
    $("#item_unit_price").html(range_to_string(unit))
    sub_total = range_multiply(unit, @params.quantity)
    total = range_add(total, sub_total)
    $("#item_total_price").html(range_to_string(sub_total))
    $("#total_price").html(range_to_string(total))
    unless @params.technique_id == 1
      if @params.quantity < @data.minimums[0]
        $("#info").html("Minimum quantity of " + @data.minimums[0] + " for imprinted items.")
      else
        $("#info").html("")
    else
      $("#info").html("No minimum for blank items.")
    mymins = []
    unless @params.quantity
      mymins = @data.minimums
    else if @params.quantity < @data.minimums[0]
      mymins = [ @params.quantity ].concat(@data.minimums.slice(0, 4))
    else if @params.quantity > @data.minimums[@data.minimums.length - 1]
      mymins = @data.minimums.slice(1, 5).concat([ @params.quantity ])
    else
      mymins[0] = Math.round(@params.quantity / 2)
      mymins[0] = @data.minimums[0]  if mymins[0] < @data.minimums[0]
      mymins[1] = Math.round((@params.quantity + mymins[0]) / 2)
      mymins[2] = @params.quantity
      mymins[4] = Math.round(@params.quantity * 2)
      mymins[4] = @data.minimums[@data.minimums.length - 1]  if mymins[4] > @data.minimums[@data.minimums.length - 1]
      mymins[3] = Math.round((mymins[4] + @params.quantity) / 2)
      last = mymins[0]
      i = 1

      while i < mymins.length
        if mymins[i] == last
          mymins.splice i, 1
          i--
        else
          last = mymins[i]
        i++
    qty_row = $("#qty_row")[0]
    price_row = $("#price_row")[0]
    return  if not qty_row or not price_row
    # !!!! DO WE NEED A CLONE?
    params = @params
    i = 0

    while i < Math.min(mymins.length, qty_row.childNodes.length - 1)
      qty = mymins[i]
      unit = @variantPrice($.extend({}, params, quantity: qty))
      qty_row.childNodes[i + 1].innerHTML = qty
      price_row.childNodes[i + 1].innerHTML = range_to_string(unit)
      cls = (if (qty == @params.quantity) then "sel" else "")
      qty_row.childNodes[i + 1].className = cls
      price_row.childNodes[i + 1].className = cls
      i++

  orderSubmit: (event) =>
    btn = $(event.target).parents().andSelf().filter('a')
    pedantic = not btn.parent().hasClass("admin")
    msg = []
    unless (@params.quantity > 0)
      msg.push "quantity (enter number to right of Quantity:)"
    else msg.push "miminum quantity of " + @data.minimums[0]  if pedantic and @params.quantity < @data.minimums[0] and @params.technique_id != 1
    groups = @_getGroups(@params)
    msg.push "a variant (Click on the appropriate box under Variants heading)"  unless groups.length == 1
    unless msg.length == 0
      alert "Must specify " + msg.join(" and ")
      return
    form = document.forms.productform
    form.price_group.value = groups[0].id
    form.variants.value = (@params.variants or []).join(",")
    form.quantity.value = @params.quantity
    form.technique.value = @params.technique_id or ""
    form.decoration.value = @params.location_id or ""
    form.unit_count.value = @params.dec_count or ""
    form.disposition.value = btn[0].id
    form.submit()
    btn.html(btn.html() + "<img src='/images/spinsmall.gif'>")


# CategoryPricing = Class.create(PricingBase, {})

$(document).ready ->
  $('#main_imgs').cycle(
        pagerEvent: 'mouseover',
        pager: '#thumbs',
        deactive: [],
        pagerAnchorBuilder: (idx, slide) ->
                $('#thumbs li')[idx]
        updateActivePagerLink: (pager, currSlide, clsName) ->
                while this.deactive[this.nextSlide]
                        this.nextSlide = this.nextSlide + 1
                        this.nextSlide = 0 if this.nextSlide == this.elements.length

                $(pager).each ()->
                        $('li', this).removeClass(clsName).eq(currSlide).addClass(clsName);
        timeout: 6000,
        setVariants: (variants) ->
          count = 0
          $('#thumbs li').each (i, v) =>
            for str in v.getAttribute("data-variants").split(' ')
              if (this.deactive[i] = (if variants then !(parseInt(str) in variants) else false))
                $(v).removeClass('active')
              else
                $('#main_imgs').cycle(i) if count == 0
                count++
                $(v).addClass('active')
          $('#main_imgs').cycle(if count <= 1 then 'pause' else 'resume')

#        onPagerEvent: (i, e) ->
#                m = $('#main_imgs')
#                if m.data('cycle.opts').deactive[i]
#                        m.cycle('resume')

        )
  set_layout

$(window).resize set_layout

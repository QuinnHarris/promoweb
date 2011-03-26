var multiplier = 1000.0
var shipping_pending = 'Retrieving Shipping Prices <img src="/images/spin30.gif"/>"';

// Duplicated
function displayMoney(val) {
  var digits = (val % (multiplier / 100)) ? 3 : 2;
  var number = (val / multiplier).toFixed(digits);
  var x = number.split('.');
  var whole = x[0];
  var decimal = x[1];

  var rgx = /(\d+)(\d{3})/;
  while (rgx.test(whole)) {
    whole = whole.replace(rgx, '$1' + ',' + '$2');
  }

  return '$' + whole + '.' + decimal
}

function parseMoney(val)
{
  if (val == '')
    return NaN;
  return parseInt(Math.round(parseFloat(val) * multiplier))
}

function roundToCent(val)
{
    return Math.round(val * 100.0 / multiplier) * (multiplier / 100.0)
}

listing = $H({})

function merge_listing(list)
{
  listing = listing.merge(list)
}

function get_listing(id)
{
  return listing.get(id)
}

function profit_margin_calculate(cells, index, price, cost)
{
    var str = ((price - cost)/multiplier).toFixed(2)
    var inputs = cells[index].getElementsByTagName('input');
    if (inputs.length == 1)
	inputs[0].value = str;
    else
	cells[index].innerHTML = displayMoney(price - cost);

    str = (price == 0) ? '' : ((price - cost) / price * 100.0).toFixed(2);
    inputs = cells[index+1].getElementsByTagName('input');
    if (inputs.length == 1)
	inputs[0].value = str;
    else
	cells[index+1].innerHTML = str + '%';
}

function order_item_quantity(node)
{
    return $A(node.getElementsByClassName('shipset')).inject(0, function(acc, inp) {
	    return acc + parseInt(inp.value);
	});
}


var table_mapping = { 1: 0, 2: 1, 4: 2, 5: 3 };
function order_item_row_vals(tr, update)
{
    var vals = [];
    for (var k = 1; k < tr.cells.length-3; k++) {
	//	    if (!table_mapping[k])
	//continue;
	var cell = tr.cells[k];
	var inputs = cell.getElementsByTagName('input');
	if (inputs.length > 0) {
	    var input = inputs[0];
	    
	    var val = parseMoney(input.value);
	    if (isNaN(val))
		val = 0.0;
	    
	    if (update && tr.hasClassName('defined')) {
		var list = get_listing(input.id);
		if (input.defaultValue == '') {
		    setField(input, val = list);
		    input.addClassName('predicate');
		}
		
		if (val == list)
		    input.removeClassName('changed');
		else
		    input.addClassName('changed');
	    }
	    
	    vals[table_mapping[k]] = val;
	} else
	    vals[table_mapping[k]] = 0.0;
    }
    return vals;
}

function order_item_calculate(table)
{
    var tbody = table.getElementsByTagName('tbody')[0];
    var tfoot = table.getElementsByTagName('tfoot')[0];
    var sum_tr = tfoot.rows[0];
    var unit_tr = tfoot.rows[1];
    
    var quantity = order_item_quantity(tbody, true);
    
    // Sum columns
    var sum = [0.0, 0.0, 0.0, 0.0];
    for (var j = 0; j < tbody.rows.length; j++) {
	var tr = tbody.rows[j];
	if (tr.cells.length == 1)
	    continue;

	var vals = order_item_row_vals(tr, true);
	
	// Apply Profit/Margin
	var price = vals[0] * quantity + vals[1];
	tr.cells[3].innerHTML = displayMoney(price);
	
	var cost = vals[2] * quantity + vals[3];
	tr.cells[6].innerHTML = displayMoney(cost);
	profit_margin_calculate(tr.cells, 7, price, cost);
	
	for (var k = 0; k < sum.length; k++)
	    sum[k] += vals[k];
    }
    
    // Apply sums
    var price = sum[0] * quantity + sum[1];
    var cost = sum[2] * quantity + sum[3];
    sum_tr.cells[1].innerHTML = displayMoney(sum[0]);
    sum_tr.cells[2].innerHTML = displayMoney(sum[1]);
    sum_tr.cells[3].innerHTML = displayMoney(price);
    sum_tr.cells[4].innerHTML = displayMoney(sum[2]);
    sum_tr.cells[5].innerHTML = displayMoney(sum[3]);
    sum_tr.cells[6].innerHTML = displayMoney(cost);

    profit_margin_calculate(sum_tr.cells, 7, price, cost)
    
    unit_tr.cells[0].innerHTML = '(Total Units: ' + quantity + ')  Unit Cost:'
    unit_tr.cells[2].innerHTML = displayMoney(sum[1] / quantity)
    unit_tr.cells[3].innerHTML = displayMoney(price / quantity)
    unit_tr.cells[5].innerHTML = displayMoney(sum[3] / quantity)
    unit_tr.cells[6].innerHTML = displayMoney(cost / quantity)
	
    return [price, cost]
}

function order_entry_calculate(table, other_price, other_cost)
{
    var tbody = table.getElementsByTagName('tbody')[0];
    var tfoot = table.getElementsByTagName('tfoot')[0];
    var sum_tr = tfoot.rows[0];
    var grand_tr = tfoot.rows[1];
	
    var price_sum = 0.0;
    var cost_sum = 0.0;
    for (var j = 0; j < tbody.rows.length; j++) {
	var tr = tbody.rows[j];
	var price = parseMoney(tr.cells[1].getElementsByTagName('input')[0].value);
	if (isNaN(price))
	    price = 0.0;
	var cost = parseMoney(tr.cells[2].getElementsByTagName('input')[0].value);
	if (isNaN(cost))
	    cost = 0.0;
	var units = parseInt(tr.cells[3].getElementsByTagName('input')[0].value);
	var total_price = price * units;
	var total_cost = cost * units;
	tr.cells[4].innerHTML = displayMoney(total_price);
	tr.cells[5].innerHTML = displayMoney(total_cost);
	profit_margin_calculate(tr.cells, 6, total_price, total_cost);

	price_sum += total_price;
	cost_sum += total_cost;
    }
	
    sum_tr.cells[2].innerHTML = displayMoney(price_sum);
    sum_tr.cells[3].innerHTML = displayMoney(cost_sum);
    profit_margin_calculate(sum_tr.cells, 4, price_sum, cost_sum);
	
    grand_tr.cells[1].innerHTML = displayMoney(price_sum + other_price);
    grand_tr.cells[2].innerHTML = displayMoney(cost_sum + other_cost);
    profit_margin_calculate(grand_tr.cells, 3, price_sum + other_price, cost_sum + other_cost);

    return [price_sum, cost_sum];
}

function input_press(event)
{ 
  var key = event.keyCode
  var keychar = String.fromCharCode(event.charCode);

  if ((key == 0) &&
      (event.target.hasClassName('money') || event.target.hasClassName('num')) &&
      ( (("0123456789").indexOf(keychar) < 0 ) &&
        !(event.target.hasClassName('money') && keychar == '.') &&
        !(event.target.hasClassName('negative') && keychar == '-')
      )
     ) {
    event.preventDefault();
    return false;
  }
  
  if (key == Event.KEY_RETURN) {
    event.target.blur();
    event.preventDefault(); // Prevent submiting form
  }

  if (key == Event.KEY_ESC) {
    var nxtSib = event.target.nextSibling;
    if (nxtSib && ('hasClassName' in nxtSib) && nxtSib.hasClassName('auto_complete'))
	return true;

    event.target.setValue(event.target.defaultValue);
    event.target.blur();
  }
  
  return true;
}

function parseField(target, value)
{
  if (target.hasClassName('null') && value == '')
    return NaN;
  if (target.hasClassName('money'))
    return parseMoney(value);
  if (target.hasClassName('num'))
    return parseInt(value);
  return value;
}

function setField(target, value)
{
    if (target.hasClassName('null') && (target.hasClassName('money') || target.hasClassName('num')) && isNaN(value))
	return '';
    if (target.hasClassName('money')) {
	var digits = (value % (multiplier / 100)) ? 3 : 2;
	return target.value = (value / multiplier).toFixed(digits);
    }
    return target.value = value;
}

function request_complete(request)
{
    if (request.responseText[0] == "{") {
	if (request.responseText != "{}") {
	    var hash = request.responseText.evalJSON();
	    for (var key in hash) {
		var cell = $(key);
		var cur = parseField(cell, cell.value);
		if (isNaN(cur))
		    setField(cell, hash[key]);
	    }
	    merge_listing(hash);
	    calculate_all();
	}
	$(request.request.options.parameters['id']).removeClassName("sending");
    } else {		
	alert("Updating cell value failed with error: " + request.responseText);
    }
}

function find_shipping(target)
{
    if (target.hasClassName('shipset')) {
	var elem = target;
	while (elem && !elem.hasClassName('item'))
	    elem = elem.parentNode;
	var shipping = elem.getElementsByClassName('shipping')[0];
	return shipping;
    }
    return false;
}

function input_update(target)
{
    if (target.hasClassName('sending'))
	return;

    if (target.hasClassName('margin') ||
	target.hasClassName('profit')) {
	// Update Price from margin
	var tr = target.parentNode.parentNode;
        var quantity = order_item_quantity(tr.parentNode);
	var vals = order_item_row_vals(tr, false);

	var cost = vals[2] * quantity + vals[3];
	var fixed = vals[1];
	var mult = multiplier / 100;

	if (target.hasClassName('margin')) {
	    var margin = parseFloat(target.value);
	    var price = cost/(1 - (margin/100.0));
	} else {
	    var profit = Math.round(parseFloat(target.value) * multiplier);
	    var price = cost + profit;
	}

	if (vals[0] * quantity > vals[1]) {
	    var price_input = tr.cells[1].getElementsByTagName('input')[0];
	    setField(price_input, Math.round( (price - fixed) / (quantity * mult) ) * mult);
	} else {
	    // No Marginal (Shipping)
	    var price_input = tr.cells[2].getElementsByTagName('input')[0];
	    setField(price_input, Math.round( price / mult ) * mult);
	}
	input_update(price_input);
	return;
    }
    
    var oldValue = target.hasClassName('predicate') ? NaN : parseField(target, target.defaultValue);

    if (target.value == '') {
	var value = get_listing(target.id);
	if (typeof(value) != 'undefined') {
	    setField(target, value);
	    target.addClassName('predicate');
	    target.defaultValue = '';
	    var newValue = NaN;
	} else {
	    if (!target.hasClassName('null') &&
		(target.hasClassName('money') || target.hasClassName('num'))) {
		target.value = target.defaultValue;
		return;
	    }
	    var newValue = target.hasClassName('null') ? NaN : '';
	    target.defaultValue = '';
	}
    } else {
	var newValue = parseField(target, target.value);
	target.defaultValue = setField(target, newValue);
	target.removeClassName('predicate');
    }
    
    if (String(newValue) == String(oldValue))
	return

  calculate_all();
  
  target.addClassName("sending");

  var shipping = find_shipping(target);
  if (shipping)
      shipping.innerHTML = shipping_pending;      
  
  new Ajax.Request('/admin/orders/set', {
	  parameters:   {
	      "id" : target.id,
		  "newValue" : newValue,
		  "oldValue" : oldValue
		  },
	      onComplete: (function(response, json) {
		      request_complete(response);
		      if (shipping)
			  get_shipping(shipping);
		  })
	      });
}

function input_change(event)
{
    var nxtSib = event.target.nextSibling;
    if (nxtSib && ('hasClassName' in nxtSib) && nxtSib.hasClassName('auto_complete') &&
	Element.getStyle(nxtSib, 'display') != 'none')
	return;

    input_update(event.target);
}

function autocomplete_change(target, selectedElement)
{
    input_update(target);
}

function input_blur(event)
{
    input_update(event.target);
}

function entry_insert(request, id, pos)
{
  var table = $(id)
  var tbody = table.getElementsByTagName('tbody')[0]

  var tr = tbody.insertRow(pos ? 3 : tbody.rows.length)
  tr.innerHTML = request.responseText
  
  setup_events(tr)
  
  calculate_all();
}

function entry_remove(request, id)
{
  if (request.status == 200 && request.responseText == "") {
    var tr = $(id).parentNode.parentNode
    var tbody = tr.parentNode
    tbody.removeChild(tr)
	calculate_all();
  }
}

function setup_events(obj)
{   
  var inputs = obj.getElementsByTagName('input')
  for (var j = 0; j < inputs.length; j++) {
    var input = inputs[j];
    if (input.type != 'text' || input.hasClassName('ignore'))
      continue;
    Event.observe(input, 'keypress', input_press)
    Event.observe(input, 'change', input_change)
    Event.observe(input, 'blur', input_blur)

    var nxtSib = input.nextSibling;
    if (nxtSib && ('hasClassName' in nxtSib) && nxtSib.hasClassName('auto_complete'))
	new Ajax.Autocompleter(input, nxtSib, '/admin/orders/auto_complete_generic', {
		afterUpdateElement: autocomplete_change
	} )
  }

  var inputs = obj.getElementsByTagName('textarea')
  for (var j = 0; j < inputs.length; j++) {
    var input = inputs[j];
    Event.observe(input, 'change', input_change)
    Event.observe(input, 'blur', input_blur)
  }
}

function calculate_all()
{
  var invoice = document.getElementsByClassName('invoice')[0];
  
  var total_price = 0;
  var total_cost = 0;
  
  var purchases = invoice.getElementsByClassName('purchase')
  for (var i = 0; i < purchases.length; i++) {
      var purchase_price = 0;
      var purchase_cost = 0;
      var divs = purchases[i].getElementsByClassName('item');
      for (var j = 0; j < divs.length; j++) {
	  var table = divs[j].getElementsByTagName('table')[0];
	  var ret = order_item_calculate(table);
	  purchase_price += ret[0];
	  purchase_cost += ret[1];
      }
      
      var div = purchases[i].getElementsByClassName('general')[0];
      if (div) {
	  var table = div.getElementsByTagName('table')[0];
	  var ret = order_entry_calculate(table, purchase_price, purchase_cost);
	  purchase_price += ret[0];
	  purchase_cost += ret[1];
      }

      total_price += purchase_price;
      total_cost += purchase_cost;
  }
  
  var generals = invoice.getElementsByClassName('general');
  var div = generals[generals.length - 1];
  var table = div.getElementsByTagName('table')[0];
  var ret = order_entry_calculate(table, total_price, total_cost);
  total_price += ret[0];
  var tax_row = $('tax');
  if (tax_row) {
      var rate = parseFloat(tax_row.cells[1].innerHTML) / 100.0;
      var tax_price = roundToCent(total_price * rate);
      tax_row.cells[2].innerHTML = displayMoney(tax_price);
      var total_row = tax_row.nextSibling.nextSibling;
      total_row.cells[1].innerHTML = displayMoney(total_price + tax_price);
  }
}


function variant_change(target)
{
    var ul = $('variants');
    var quantity = order_item_quantity(ul);

    if (!confirm('Set ' + quantity + ' units for ' + target.text + ' only'))
	return;
    
    $A(ul.getElementsByClassName('shipset')).each(function(inp) {
	    inp.value = '0';
	});

    var imprint = $A(ul.getElementsByClassName('imprint')).inject([], function(acc, inp) {
	    var value = inp.value;
	    inp.value = '';
	    return value.empty() ? acc : acc.compact().concat([value]);
	}).join(', ');

    var quant_node = target.parentNode.getElementsByClassName('shipset')[0];
    var oldValue = parseInt(quant_node.value);
    quant_node.value = quantity;
    target.parentNode.getElementsByClassName('imprint')[0].value = imprint;

    quant_node.addClassName("sending");
    new Ajax.Request('/admin/orders/variant_change', {
	    parameters:   {
		"id" : quant_node.id,
		    "oldValue" : oldValue,
		    "newValue" : quantity,
		    "imprint" : imprint
		    },
		onComplete: request_complete
		});
}

function shipping_change(target)
{
    target.addClassName("sending");
    new Ajax.Request('/admin/orders/shipping_set', {
	    parameters:   {
		"id" : target.id,
		    "value" : target.value  },
		onComplete: request_complete
		});
}

function get_shipping(s)
{
    var table = s.parentNode.parentNode.parentNode;
    new Ajax.Updater(s, '/admin/orders/shipping_get/'+table.id.split('-')[1], {asynchronous:true, evalScripts:true});
}

function get_all_shipping()
{
    var shippings = document.getElementsByClassName('shipping');
    for (var i = 0; i < shippings.length; i++) {
	var s = shippings[i];
	if (s.hasClassName('pending')) {
	    s.innerHTML = shipping_pending
	    get_shipping(s);
	} else {
	    var inputs = s.getElementsByTagName('input');
	    if (inputs.length == 1) {
		Event.observe(inputs[0], 'change', shipping_change);
	    }
	}
    }
}

function show(name)
{
    var elem = $(name);
    if (elem.hasClassName('hide'))
	elem.removeClassName('hide');
    else
	elem.addClassName('hide');
}

function initialize(){
  var invoice = document.getElementsByClassName('invoice')[0];
  if (invoice) {
	setup_events(invoice)
	calculate_all();
	get_all_shipping();
  }
}
window.onload = initialize

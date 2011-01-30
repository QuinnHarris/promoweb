/* DUPLICATED */
function id_parse(str) {
  var arr = str.split('-')
  return parseInt(arr[1])
}

function num_keypress(myfield, e) {
  var key;
  var keychar;

  if (window.event)
    key = window.event.keyCode;
  else if (e)
    key = e.which;
  else
    return true;
 
  keychar = String.fromCharCode(key);
  
  if (keychar == '0' && myfield.value.length == 0)
    return false;

// control keys
  if ((key==null) || (key==0) || (key==8) ||
      (key==9) || (key==13) || (key==27) )
    return true;
  else if ((("0123456789").indexOf(keychar) > -1))
    if (myfield.value.length > 5)
      return false;
    else
      return true;
  else
    return false;
}

var postalcode
function update_shipping(className) {
  $A(document.getElementsByClassName(className)).each(function(div) {
    div.innerHTML = 'Retrieving Shipping Prices <img src="/images/spin30.gif"/>"'
    new Ajax.Updater(div.id, '/order/shipping_get/'+id_parse(div.id)+"?postalcode="+postalcode, {asynchronous:true, evalScripts:true})
  })
}

function change_postalcode(value) {
  if (value.length == 5 && postalcode != value) {
    postalcode = value
    update_shipping('shipping')
  }
}


window.onload = function() {
  postalcode = $('postalcode').value
  if (postalcode.length == 5)
    update_shipping('pending')
}
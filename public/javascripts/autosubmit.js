function setup_autosubmit(event) {
	Event.stopObserving(event.currentTarget, 'change')
	Event.observe(window, 'unload',
	function() {
	  var forms = document.getElementsByTagName('form')
	  for (var i = 0; i < forms.length; i++)
	    var form = forms[i]
	    if (form.method == "post")
	      new Ajax.Request(form.action, {asynchronous:true, evalScripts:false, parameters:(Form.serialize(form) + '&ajax=true')});
	})
}

function autosubmit_initialize() {
  var forms = document.getElementsByTagName('form')
  for (var i = 0; i < forms.length; i++)
    if (forms[i].method == "post")
	  Event.observe(forms[i], 'change', setup_autosubmit)
}

/*Event.observe(document, 'onload', autosubmit_initialize);*/
window.onload = autosubmit_initialize


function enable_disable_forum(object, input) {
    var elements = $(object).getElementsByTagName('input')
    for (i = 0; i < elements.length; ++i) {
	if (elements[i] != input)
	    elements[i].disabled = !input.checked;
    }
}

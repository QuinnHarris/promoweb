/* JS */
if ("undefined" == typeof(MOPChrome)) {
    var MOPChrome = {};
};

MOPChrome.messageOverlay = {
    _status_url : null,

    init : function() {
	var messagepane = document.getElementById("messagepane");
	messagepane.addEventListener("load", MOPChrome.messageOverlay.messageLoad, true);

	var status = document.getElementById('mop-status-text');
	status.onclick = MOPChrome.messageOverlay.messageClick;
	
	var prefs = Components.classes["@mozilla.org/preferences-service;1"]
	  .getService(Components.interfaces.nsIPrefService)
 	  .getBranch("extensions.mop.");

	MOPChrome.messageOverlay._status_url = prefs.getCharPref("message.status_url");
    },

    requestLoad : function() {
	var data = JSON.parse(MOPChrome.messageOverlay.request.responseText);
	var status = document.getElementById('mop-status-text');
	status.childNodes[0].nodeValue = data.text;
	MOPChrome.messageOverlay.follow_uri = data.uri
	status.className = 'text-link';
    },

    messageClick : function() {
	var uri = Components.classes["@mozilla.org/network/io-service;1"].getService(Components.interfaces.nsIIOService).newURI( MOPChrome.messageOverlay.follow_uri, null, null);
	Components.classes["@mozilla.org/uriloader/external-protocol-service;1"].getService(Components.interfaces.nsIExternalProtocolService).loadURI(uri, null);
    },

    messageLoad : function() {
	if (gFolderDisplay.selectedCount > 1)
	    return;
	var msgHdr = gFolderDisplay.selectedMessage;
	if (!msgHdr)
	    return;

	var status_uri = MOPChrome.messageOverlay._status_url;
	status_uri += "?author=" + escape(msgHdr.author);
	status_uri += "&recipients=" + escape(msgHdr.recipients);
	status_uri += "&subject=" + escape(msgHdr.subject);
	status_uri += "&date=" + escape(msgHdr.date);

	MOPChrome.messageOverlay.follow_uri = status_uri;

	var status = document.getElementById('mop-status-text');
	status.childNodes[0].nodeValue = "LOADING";
	status.className = '';

	var request = new XMLHttpRequest();
	request.open("GET", status_uri, true);	
	request.onload = MOPChrome.messageOverlay.requestLoad;
	request.send(null);
	MOPChrome.messageOverlay.request = request;
    },
};

window.addEventListener("load", MOPChrome.messageOverlay.init, false);

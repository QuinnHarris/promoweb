// ry dahl <ry@tinyclouds.org>
// Don't Poll. Pull!
// version 0.1
Ajax.Pull = Class.create(Ajax.Request, {
  initialize: function($super, url, options) {
    options['method'] = options['method'] || 'get';
	$super(url, options)
	
    this.handler = options.handler;
    this.frequency = options.frequency || 2.0;
	
    this.startPuller();
  },
  
  startPuller: function() {
    this.pullPointer = 0;
    this.puller = new PeriodicalExecuter(this.pull.bind(this), this.frequency);
  },
  
  pull: function() {
    if(this.transport.readyState < 3) {
      return; // not receiving yet
    } else if (this._complete) {
      this.puller.stop(); // this is our last pull
    }
    
    var slice = this.transport.responseText.slice(this.pullPointer);
    
    (this.options.pullDebugger || Prototype.emptyFunction)(
        'slice: <code>' + slice + '</code>');  
    
    slice.extractJSON().each((function(statement) {
      (this.options.pullDebugger || Prototype.emptyFunction)(
          'extracted statement: <code>' + statement + '</code>');
      this.handler(eval( '(' + statement + ')' ));
      this.pullPointer += statement.length + 1;
    }).bind(this));
    
  }
});


Object.extend(String.prototype, {
  extractJSON: function() {
    var insideString = false;
    var sBrackets = cBrackets = parens = 0;
    var statements = new Array();
    var start = i = 0;
    for(i = 0; i < this.length; i++) {
      if( cBrackets < 0 || sBrackets < 0 || parens < 0 ) {
        // raise syntax error?
      }
      if(insideString) {
        switch(this[i]) {
          case '\\': i++; break;
          case '"': insideString = false; break;
        }
      } else {
        switch(this[i]) {
          case '"': insideString = true; break;
          case '{': cBrackets++; break;
          case '}': cBrackets--; break;
          case '[': sBrackets++; break;
          case ']': sBrackets--; break;
          case '(': parens++; break;
          case ')': parens++; break;
          case ';':
            if(cBrackets == 0 && sBrackets == 0 && parens == 0) {
              statements.push(this.slice(start, i));
              start = i+1;
            }
        }
      }
    }
    return statements;
  }
});


function appendDebug(text) {
  li = document.createElement('li');
  li.innerHTML = text;
  $('debug').appendChild(li);
}

var UploadProgress = {
  uploading: null,
  
  begin: function(upload_id) {
    //$('upload-console').src = '/files/upload_progress?upload_id=' + upid;

    new Ajax.Pull('/order/upload_progress?upload_id=' + upload_id, {
      // TODO:
      // poll_url is not yet implemented in Ajax.Pull. this is needed for
      // older versions of safari due to a bug.
      //
      //poll_url: '/files/upload_progress?single&upload_id=' + upload_id,
      //pullDebugger: appendDebug,
      handler: this.update.bind(this)
    });
    
    this.uploading = true;
    this.StatusBar.create();
	$('add-button').style.display = 'none';
  },
  
  update: function(json) {
    
    if(json["state"] == 'starting') {

    } else if(json["state"] == 'done') {
      this.uploading = false;
      this.StatusBar.finish();
	  location.reload(true);
    } else if(json["state"] == 'error') {
      this.error(json['message']);
      
    } else if(json["state"] == 'uploading') {
      var status = json["received"] / json["size"];
      var statusHTML = "Progress: " + status.toPercentage() + " - <small>" + json["received"].toHumanSize() + 
        ' of ' + json["size"].toHumanSize() + " uploaded.</small>";
      this.StatusBar.update(status, statusHTML);
      
    } else {
      this.error('Unknown upload progress state received: ' + json['state']);
    }
  },
  
  error: function(msg) {
    if(!this.uploading) return;
    this.uploading = false;
    if(this.StatusBar.statusText) this.StatusBar.statusText.innerHTML = msg || 'Error Uploading File';
  },
  
  StatusBar: {
    statusBar: null,
    statusText: null,
    statusBarWidth: 500,
  
    create: function() {
      this.statusBar  = this._createStatus('status-bar');
      this.statusText = this._createStatus('status-text');
/*		this.statusText = this.statusBar;*/
      this.statusText.innerHTML  = 'Starting Upload.  Please Wait .';
      this.statusBar.style.width = '0%';
	  $('progress-bar').style.display = 'block';
    },

    update: function(status, statusHTML) {
      this.statusText.innerHTML = statusHTML;
/*      this.statusBar.style.width = Math.floor(this.statusBarWidth * status);*/
      this.statusBar.style.width = status.toPercentage();
    },

    finish: function() {
      this.statusText.innerHTML  = 'File Uploaded.  Please wait for server to process image.';
      this.statusBar.style.width = '100%';
    },
    
    _createStatus: function(id) {
      el = $(id);
      if(!el) {
        el = document.createElement('span');
        el.setAttribute('id', id);
        $('progress-bar').appendChild(el);
      }
      return el;
    }
  },
  
  FileField: {
    add: function() {
      new Insertion.Bottom('file-fields', '<p style="display:none"><input id="data" name="data" type="file" /> <a href="#" onclick="UploadProgress.FileField.remove(this);return false;">x</a></p>')
      $$('#file-fields p').last().visualEffect('blind_down', {duration:0.3});
    },
    
    remove: function(anchor) {
      anchor.parentNode.visualEffect('drop_out', {duration:0.25});
    }
  }
}

Number.prototype.bytes     = function() { return this; };
Number.prototype.kilobytes = function() { return this *  1024; };
Number.prototype.megabytes = function() { return this * (1024).kilobytes(); };
Number.prototype.gigabytes = function() { return this * (1024).megabytes(); };
Number.prototype.terabytes = function() { return this * (1024).gigabytes(); };
Number.prototype.petabytes = function() { return this * (1024).terabytes(); };
Number.prototype.exabytes =  function() { return this * (1024).petabytes(); };
['byte', 'kilobyte', 'megabyte', 'gigabyte', 'terabyte', 'petabyte', 'exabyte'].each(function(meth) {
  Number.prototype[meth] = Number.prototype[meth+'s'];
});

Number.prototype.toPrecision = function() {
  var precision = arguments[0] || 2;
  var s         = Math.round(this * Math.pow(10, precision)).toString();
  var pos       = s.length - precision;
  var last      = s.substr(pos, precision);
  return s.substr(0, pos) + (last.match("^0{" + precision + "}$") ? '' : '.' + last);
}

// (1/10).toPercentage()
// # => '10%'
Number.prototype.toPercentage = function() {
  return (this * 100).toPrecision() + '%';
}

Number.prototype.toHumanSize = function() {
  if(this < (1).kilobyte())  return this + " Bytes";
  if(this < (1).megabyte())  return (this / (1).kilobyte()).toPrecision()  + ' KB';
  if(this < (1).gigabytes()) return (this / (1).megabyte()).toPrecision()  + ' MB';
  if(this < (1).terabytes()) return (this / (1).gigabytes()).toPrecision() + ' GB';
  if(this < (1).petabytes()) return (this / (1).terabytes()).toPrecision() + ' TB';
  if(this < (1).exabytes())  return (this / (1).petabytes()).toPrecision() + ' PB';
                             return (this / (1).exabytes()).toPrecision()  + ' EB';
}

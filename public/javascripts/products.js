function getCookie( name ) {
  var start = document.cookie.indexOf( name + "=" );
  var len = start + name.length + 1;
  if ( ( !start ) && ( name != document.cookie.substring( 0, name.length ) ) ) {
    return null;
  }
  if ( start == -1 ) return null;
  var end = document.cookie.indexOf( ";", len );
  if ( end == -1 ) end = document.cookie.length;
  return unescape( document.cookie.substring( len, end ) );
}

function setCookie( name, value, expires, path, domain, secure ) {
  var today = new Date();
  today.setTime( today.getTime() );
  if ( expires ) {
    expires = expires * 1000 * 60 * 60 * 24;
  }
  var expires_date = new Date( today.getTime() + (expires) );
  document.cookie = name+"="+escape( value ) +
    ( ( expires ) ? ";expires="+expires_date.toGMTString() : "" ) + //expires.toGMTString()
    ( ( path ) ? ";path=" + path : "" ) +
    ( ( domain ) ? ";domain=" + domain : "" ) +
    ( ( secure ) ? ";secure" : "" );
}

function deleteCookie( name, path, domain ) {
  if ( getCookie( name ) ) document.cookie = name + "=" +
    ( ( path ) ? ";path=" + path : "") +
    ( ( domain ) ? ";domain=" + domain : "" ) +
    ";expires=Thu, 01-Jan-1970 00:00:01 GMT";
}


var PricingBase = Class.create({
	initialize: function(data) {
	    this.data = data;
	},

	_decorationFind: function(id) {
	    return this.data.decorations.find(function(dec) { return dec.id == id });
	},

	_decorationPriceFunc: function(entry, quantity) {
	    return Math.round(entry.price_marginal * (1 + entry.price_const * Math.pow(quantity, entry.price_exp)))
	},

	_decorationPriceMult: function(entry, value, mult) {
	    var num = Math.floor((value - 1 - entry.offset) / entry.divisor);
	    return num ? (num * mult) : 0;
	},

	_decorationCountLimit: function(params, dec) {
	    if (params.location_id)
		return dec.locations.find(function(e) { return e.id == params.location_id}).limit;
	    else
		return dec.locations.collect(function(e) { return e.limit }).min();
	},

	decorationCountLimit: function(params) {
	    var dec = this._decorationFind(params.technique_id);
	    if (!dec)
		return null;
	    return this._decorationCountLimit(params, dec);
	},

	decorationPrice: function(params) {
	    var dec = this._decorationFind(params.technique_id);
	    if (!dec)
		return NaN;

	    var fixed = { min: 2147483647, max: 0 };
	    var marginal = { min: 2147483647, max: 0 };

	    var count_limit = this._decorationCountLimit(params, dec);
    
	    dec.entries.reverse().find(function(entry) {
		    if (params.dec_count && entry.minimum > params.dec_count)
			return;
	    
		    var fixed_val = entry.fixed.price_fixed;
		    var marginal_val = this._decorationPriceFunc(entry.fixed, params.quantity);
		    if (!params.dec_count) {
			range_apply(fixed, fixed_val);
			range_apply(marginal, marginal_val);
		    }
		    
		    var value = params.dec_count ? params.dec_count : count_limit;
		    // Limit ?
		    // if (value > (breaks[j+1] || [])[0])
		    // 	 value = breaks[j+1][0];
		    
		    if (value) {
			fixed_val += this._decorationPriceMult(entry.fixed, value, entry.marginal.price_fixed);
			marginal_val += this._decorationPriceMult(entry.marginal, value, this._decorationPriceFunc(entry.marginal, params.quantity));
			
			range_apply(fixed, fixed_val);
			range_apply(marginal, marginal_val);
		    }		    
		    
		    return params.dec_count;
		}.bind(this));

	    return { fixed: fixed, marginal: marginal };
	},

	_priceSingle: function(grp, n) {
	    var fixed = NaN;
	    var marginal = NaN;
    
	    grp.breaks.find(function(brk) {
		    if (brk.minimum > n)
			return true;
		    fixed = brk.fixed;
		    marginal = brk.marginal;
		});
    
	    if (!marginal)
		return { fixed: 2147483647, marginal: 2147483647 };
  
	    return { fixed: 0.0,
		    marginal: Math.round(fixed/(n*10.0))*10 + Math.round((marginal + grp.constant * Math.pow(n, grp.exp))/10.0)*10 };
	},

	_priceGroup: function(groups, qty) {
	    var fixed = { min: 2147483647, max: 0 };
	    var marginal = { min: 2147483647, max: 0 };

	    groups.each(function(group) {
		    var prices = this._priceSingle(group, qty);
		    range_apply(fixed, prices.fixed);
		    range_apply(marginal, prices.marginal);
		}.bind(this));
    
	    return { min: marginal.min + (fixed.min / qty),
		    max: marginal.max + (fixed.max / qty) };
	},

	_getGroups: function(params) {
	    if (!params.variants)
		return this.data.groups;
	    return this.data.groups.findAll(function(entry) {
		    return entry.variants.intersect(params.variants).length > 0;
		});
	},

	variantPrice: function(params) {
	    var groups = this._getGroups(params);
	    var quantity = (params.technique_id == 1) ? Math.max(this.data.minimums[0], params.quantity) : params.quantity;
	    return this._priceGroup(groups, quantity);
	}	
    });

var ProductPricing = Class.create(PricingBase, {
	initialize: function($super, data) {
	    $super(data);

	    this.params = {  };

	    this.quantity = $('quantity');
	    this.unit = $('unit_value');

	    // Setup Quantity
	    var quantity = parseInt(getCookie('quantity'));
	    if (quantity) {
		this.quantity.value = quantity;
		this.params.quantity = quantity;
	    }

	    // Setup Decoration Technique
	    var technique_id = parseInt(getCookie('technique'));
	    var li = null;
	    if (technique_id) {
		li = $('tech-' + technique_id);
		if (li)
		    this.params.dec_count = parseInt(getCookie('count'));
	    }

	    if (!li) {
		li = $$('#techniques .sel')[0];
		if (li) technique_id = id_parse(li.id);
	    }

	    this.params.technique_id = technique_id;
	    if (li) { 
		this.applyTechnique(li);
		Event.observe(this.unit, 'keydown', this.onKeyPress.bindAsEventListener(this, this.changeCount));
	    }
		
	    this.applyPrices();

	    
	    Event.observe(this.quantity, 'keydown', this.onKeyPress.bindAsEventListener(this, this.changeQuantity));

	    $$('#variants dt a').each(function(a) {
		    Event.observe(a, 'mousedown', this.onMouseClrVariant.bindAsEventListener(this));
		}.bind(this));
	    
	    $$('#variants dd a').each(function(a) {
		    Event.observe(a, 'mousedown', this.onMouseSelVariant.bindAsEventListener(this));
		}.bind(this));

	    $$('#techniques a').each(function(a) {
		    Event.observe(a, 'mousedown', this.onMouseTechnique.bindAsEventListener(this));
		}.bind(this));

	    $$('a.submit').each(function(a) {
		    Event.observe(a, 'mousedown', this.orderSubmit.bindAsEventListener(this));
		}.bind(this));

	},

	_unselectVariants: function(ul) {
	    $A(ul.childNodes).each(function(li) {
		    li.className = '';
		});
	},


	applyTechnique: function(li) {
	    var ul = li.parentNode;
	    this._unselectVariants(ul);
	    li.className = 'sel';

	    var dec = this._decorationFind(this.params.technique_id);
	    if (!dec)
		return;

	    var ul = $('locations');
	    var dd = ul.parentNode;
	    var dt = dd.previousSibling;
    
	    if (dec.locations.length > 0) {
		var elems = [];
		dec.locations.each(function(loc) {
			elems.push('<li id="dec-' + loc.id + '"><a href="#"><span>' + loc.display + '</span></a></li>');		
		    });
		ul.innerHTML = elems.join('');
		dd.style.display = '';
		dt.style.display = '';

		$$('#locations li a').each(function(li) {
			Event.observe(li, 'mousedown', this.onMouseLocation.bindAsEventListener(this));
		    }.bind(this));
	    } else {
		dd.style.display = 'none';
		dt.style.display = 'none';
	    }

    
	    var inp = $('unit_value');
	    if (inp) {
		if (!this.params.dec_count)
		    this.params.dec_count = dec.unit_default;

		var dd = inp.parentNode;
		var dt = dd.previousSibling;
		
		if (dec.unit_name && dec.unit_name.length > 0) {
		    dt.innerHTML = '<span>Number of ' + dec.unit_name + '(s):</span>';
		    dt.style.display = '';
		    dd.style.display = '';
		    if (this.params.dec_count)
			inp.value = this.params.dec_count;
		} else {
		    dt.style.display = 'none';
		    dd.style.display = 'none';
		}
	    }

	    $('dec_desc').innerHTML = li.getElementsByTagName('span')[0].innerHTML;
	    $('sample').style.display = (this.params.technique_id == 1) ? 'none' : ''
	},

	onMouseTechnique: function(event) {
	    var li = event.findElement('li');
	    this.params.technique_id = id_parse(li.id);
	    setCookie('technique', this.params.technique_id);

	    this.applyTechnique(li);
	    this.applyPrices();

	    return true;
	},

	onMouseLocation: function(event) {
	    var li = event.findElement('li');
	    var ul = li.parentNode;
	    this._unselectVariants(ul);
	    li.className = 'sel';
  
	    this.params.location_id = id_parse(li.id)
	},

	setVariants: function() {
	    var variants = null;
	    $$('#variants .sel').each(function(li) {
		    var list = li.getAttribute('data-variants').split(' ').collect(function(str) {
			    return parseInt(str);
			});
		    variants = variants ? variants.intersect(list) : list;
		});
	    this.params.variants = variants;

	    if (cycler)
		cycler.setVariants(variants);
	},

	onMouseSelVariant: function(event) {
	    var li = event.findElement('li');
	    var ul = li.parentNode;
	    this._unselectVariants(ul);
	    li.className = 'sel';

	    this.setVariants();
	    this.applyPrices();
	},

	onMouseClrVariant: function(event) {
	    var dd = event.findElement('dt').nextSiblings().first();
	    var ul = dd.getElementsByTagName('ul')[0];
	    this._unselectVariants(ul);

	    this.setVariants();
	    this.applyPrices();
	},

	onKeyPress: function(event, after_func) {
	    var keychar = String.fromCharCode(event.keyCode);
	    if (keychar == '0' && event.target.value.length == 0) {
		event.preventDefault();
		return false;
	    }

	    if ((("0123456789").indexOf(keychar) > -1) ||
		(event.keyCode == Event.KEY_BACKSPACE) ||
		(event.keyCode == Event.KEY_TAB) ||
		(event.keyCode == Event.KEY_RETURN) ||
		(event.keyCode == Event.KEY_ESC) ||
		(event.keyCode == Event.KEY_LEFT) ||
		(event.keyCode == Event.KEY_UP) ||
		(event.keyCode == Event.KEY_RIGHT) ||
		(event.keyCode == Event.KEY_DOWN) ||
		(event.keyCode == Event.KEY_DELETE) ||
		(event.keyCode == Event.KEY_HOME) ||
		(event.keyCode == Event.KEY_END) ||
		(event.keyCode == Event.KEY_PAGEUP) ||
		(event.keyCode == Event.KEY_PAGEDOWN) ||
		(event.keyCode == Event.KEY_INSERT) ) {
		after_func.bind(this).defer();
		return true;
	    }

	    event.preventDefault();
	    return false;
	},

	changeQuantity: function(event) {
	    this.params.quantity = parseInt(this.quantity.value);
	    setCookie('quantity', this.params.quantity);
	    this.applyPrices();
	    
	},
	
	changeCount: function(event) {
	    var count_limit = this.decorationCountLimit(this.params);
	    this.params.dec_count = parseInt(this.unit.value);
	    if (this.params.dec_count > count_limit) {
		this.params.dec_count = count_limit;
		this.unit.value = this.params.dec_count;
	    }
	    setCookie('count', this.params.dec_count);
	    
	    this.applyPrices();
	},

	applyPrices: function() {
	    var dec_price = this.decorationPrice(this.params);
	    if (dec_price) {
		$('dec_unit_price').innerHTML = range_to_string(dec_price.marginal);
		var total = range_multiply(dec_price.marginal, this.params.quantity);
		$('dec_total_price').innerHTML = range_to_string(total);
		$('dec_fixed_price').innerHTML = range_to_string(dec_price.fixed);
		total = range_add(total, dec_price.fixed);
	    } else
		var total = { min: 0.0, max: 0.0 };
	    
	    $$('#prices .dec').each(function(row) {
		    row.style.display = (total.max == 0.0) ? 'none' : '';
		});
	    $('addtoorder').rowSpan = (total.max == 0.0) ? 2 : 4;

	    var unit = this.variantPrice(this.params);
	    $('item_unit_price').innerHTML = range_to_string(unit);
	    var sub_total = range_multiply(unit, this.params.quantity);
	    total = range_add(total, sub_total);
	    $('item_total_price').innerHTML = range_to_string(sub_total);

	    $('total_price').innerHTML = range_to_string(total);


	    if (this.params.technique_id != 1)
		if (this.params.quantity < this.data.minimums[0])
		    $('info').innerHTML = "Minimum quantity of " + this.data.minimums[0] + " for imprinted items.";
		else
		    $('info').innerHTML = '';
	    else
		$('info').innerHTML = "No minimum for blank items." ;

	    
	    var mymins = [];
    
	    if (!this.params.quantity) {
		mymins = this.data.minimums;
	    } else if (this.params.quantity < this.data.minimums[0]) {      
		mymins = [this.params.quantity].concat(this.data.minimums.slice(0,4));
	    } else if (this.params.quantity > this.data.minimums.last()) {
		mymins = this.data.minimums.slice(1, 5).concat([this.params.quantity]);
	    } else {
		mymins[0] = Math.round(this.params.quantity / 2);
		if (mymins[0] < this.data.minimums[0])
		    mymins[0] = this.data.minimums[0];
		mymins[1] = Math.round((this.params.quantity + mymins[0]) / 2);
		mymins[2] = this.params.quantity;
		mymins[4] = Math.round(this.params.quantity * 2);
		if (mymins[4] > this.data.minimums.last())
		    mymins[4] = this.data.minimums.last();
		mymins[3] = Math.round((mymins[4] + this.params.quantity) / 2);
		var last = mymins[0];
	
		for (var i=1; i < mymins.length; i++)
		    if (mymins[i] == last) {
			mymins.splice(i,1);
			i--;
		    } else
			last = mymins[i];
	    }

	    var qty_row = $('qty_row');
	    var price_row = $('price_row');
	
	    var params = $H(this.params).clone();
	    for (var i = 0; i < mymins.length; i++) {
		var qty = mymins[i];

		var unit = this.variantPrice(Object.extend(params, { quantity: qty }));
		qty_row.childNodes[i+1].innerHTML = qty;
		price_row.childNodes[i+1].innerHTML = range_to_string(unit);

		var cls = (qty == this.params.quantity) ? 'sel' : '';
		qty_row.childNodes[i+1].className = cls;
		price_row.childNodes[i+1].className = cls;
	    }
	},

	orderSubmit: function(event) {
	    var btn = event.currentTarget;
	    var pedantic = !btn.parentNode.hasClassName('admin');

	    var msg = [];

	    if (!(this.params.quantity > 0))
		msg.push('quantity (enter number to right of Quantity:)');
	    else if (pedantic && this.params.quantity < this.data.minimums[0] && this.params.technique_id != 1)
		msg.push('miminum quantity of ' + this.data.minimums[0]);
	    
	    var groups = this._getGroups(this.params);
	    if (groups.length != 1)
		msg.push('a variant (Click on the appropriate box under Variants heading)');
    
	    if (msg.length != 0) {
		alert("Must specify " + msg.join(' and '));
		return;
	    }

	    var form = document.forms.productform;
	    form.price_group.value = groups[0].id;
	    form.variants.value = (this.params.variants || []).join(',');
	    form.quantity.value = this.params.quantity;
	    form.technique.value = this.params.technique_id || '';
	    form.decoration.value = this.params.location_id || '';
	    form.unit_count.value = this.params.dec_count || '';
	    form.disposition.value = btn.id;
	    form.submit();
	}
    });

var CategoryPricing = Class.create(PricingBase, {
	
    });

function id_parse(str) {
  var arr = str.split('-')
  return parseInt(arr[1])
}

function int_to_money(val) {
    var negative = val < 0;
    if (negative)
	val = -val;
    var number = (val / 1000).toFixed(2);
    if (number.length > 6) {
	var mod = number.length % 3;
	var output = (mod > 0 ? (number.substring(0,mod)) : '');
	var max = Math.floor(number.length / 3);
	for (i=0 ; i < max; i++) {
	    if (((mod == 0) && (i == 0)) || (i == max - 1))
		output += number.substring(mod+ 3 * i, mod + 3 * i + 3);
	    else
		output+= ',' + number.substring(mod + 3 * i, mod + 3 * i + 3);
	}
    } else
	var output = number;

    return (negative ? '-' : '') + '$' + output;
}

function array_to_range(array) {
  [array.min(), array.max()]
}

function num_to_str(num) {
  if (num >= 2000000000)
    return 'Call'  
  else if (!num && num != 0)
    return ''
  else
    return int_to_money(num)
}

function range_to_string(range) {
    if ((range.min || 0) == (range.max || 0))
	return num_to_str(range.min);
    else
	return num_to_str(range.min) + '<br/>to ' +
	    num_to_str(range.max);
    return NaN
}

function range_multiply(range, n) {
    return { min: range.min * n, max: range.max * n }
}

function range_add(a, b) {
    return { min: a.min + b.min, max: a.max + b.max };
}

function range_apply(range, val) {
    range.min = Math.min(range.min, val);
    range.max = Math.max(range.max, val);
    return range
}



/**
 * protocycle.js - Cycle extension for Prototype JS library
 * --------------------------------------------------------
 * Copied and modified from:
 * http://www.omcore.net/blog/33/introducing-protocycle-an-easy-way-to-fade-between-images/
 * http://www.flyspain.co.uk/
 *
 * v1.0, Oct 1st 2009
 *
 */

var Protocycle = Class.create({
	initialize: function(container, thumbs, options) {  
            this.options = {
                fx: 'fade', // 'fade' or 'none'
                timeout: 6000, // time between slide changes (in milliseconds)
                speed: 500, // time taken to do the transition (in milliseconds)
                sync: true, // true if in/out transitions should occur simultaneously 
                containerResize: true // automatically resize container to fit largest slide 
            }
            Object.extend(this.options, options || {});  
            
            
            // automatically set timeout option if the container element has a classname of 
            // timeout[n] where n is the desired value in milliseconds
            $w(container.className).each(function(classname) {
		    var result = classname.match(/timeout\[([0-9]+)\]/);
		    
		    if(result != null) {
			this.options.timeout = result[1];
		    }
		}.bind(this));
          
            var slideHeight = 0; // default
            var slideWidth = 0; // default
            this.currentSlide = 0;
            
            // If the holder isnt valid then stop here
            if(!container) return false;
            
            container.setStyle({position: 'relative'});
            this.slides = container.childElements();
	    this.thumbs = thumbs;
            this.totalSlides = this.slides.size();
	    this.active = this.slides.collect(function() { return true; });
            
            // Work out the dimensions of the biggest slide, also hides all but the first slide
            var first = true;
            this.slides.each(function(el) {
		    var dimensions = el.getDimensions();
    
		    if(dimensions.height > slideHeight) slideHeight = dimensions.height;
		    if(dimensions.width > slideWidth) slideWidth = dimensions.width;
		    
		    if(!first) {
			el.setStyle({display: 'none'});
		    }
		    first = false;
		    el.setStyle({position: 'absolute'});
		});
            
            // Automatically resize container?
            if(this.options.containerResize) {
                container.setStyle({height: slideHeight+'px', width: slideWidth+'px'});
            }
            
            if(this.totalSlides > 1) {
                this.executer = new PeriodicalExecuter(this.nextSlide.bind(this), (this.options.timeout/1000));

		this.thumbs.each(function(el) {
			Event.observe(el, 'mouseover', this.onThumbEvent.bind(this));
			Event.observe(el, 'mouseout', this.onThumbEvent.bind(this));
		    }.bind(this));
            }
	},

	onThumbEvent: function(event)
	{
	    var nextSlide = 0;
	    var target = event.target;

	    this.thumbs.find(function(el) {
		    if (el == event.target || event.target.childOf(el))
			return true;
		    nextSlide++;
		});

	    if (event.type == 'mouseover') {
		this.executer.stop();
		this.setSlide(nextSlide, true);
	    }

	    if (event.type == 'mouseout') {
		this.executer = new PeriodicalExecuter(this.nextSlide.bind(this), (this.options.timeout/1000));
	    }
	},

	setSlide: function(nextSlide, instant)
	{
            if(this.options.fx == 'fade' && !instant) {
                var currentOpts = {from: 1.0, to: 0.0, duration: (this.options.speed/1000), afterFinish: function(effect) { effect.element.setStyle({display: 'none'}); }};
                var nextOpts = {from: 0.0, to: 1.0, duration: (this.options.speed/1000), afterSetup: function(effect) { effect.element.setStyle({display: 'block'});   }};
		
                if(this.options.sync) {
                    // Run both animations in parallel.
                    Object.extend(currentOpts, {sync: true});  
                    Object.extend(nextOpts, {sync: true}); 
                    
                    new Effect.Parallel([
					 new Effect.Opacity(this.slides[this.currentSlide], currentOpts),
					 new Effect.Opacity(this.slides[nextSlide], nextOpts)
					 ]);
                } else {
                    // Run in and out animation after one another.
                    Object.extend(currentOpts, {queue: 'end'});  
                    Object.extend(nextOpts, {queue: 'end'}); 
                    
                    new Effect.Opacity(this.slides[this.currentSlide], currentOpts);
                    new Effect.Opacity(this.slides[nextSlide], nextOpts);
                }
            } else {
                // If no fx has been set then just do a simple swap
                this.slides[this.currentSlide].setStyle({display: 'none'});
                this.slides[nextSlide].setStyle({display: 'block', opacity: 1.0});
            }

	    this.thumbs[this.currentSlide].removeClassName('sel')
            this.thumbs[nextSlide].addClassName('sel');

	    this.currentSlide = nextSlide;
	},
        
        nextSlide: function()
        {
	    var nextSlide = this.currentSlide + 1;
	    while (!this.active[nextSlide] && nextSlide != this.currentSlide) {
		nextSlide++;
		if(nextSlide >= this.totalSlides) nextSlide = 0;
	    }

	    if (nextSlide == this.currentSlide)
		return;
        
	    this.setSlide(nextSlide);
        },

	setVariants: function(variants)
	{
	    var count = 0;
	    this.active = this.thumbs.collect(function(li) {
		    var vars = li.getAttribute('data-variants').split(' ').collect(function(str) {
			    return parseInt(str);
			});
		    if (vars.intersect(variants).length > 0) {
			li.addClassName('active');
			count++;
			return true;
		    } else {
			li.removeClassName('active');
			return false;
		    }			
		});

	    if (count == 0) {
		this.active = this.thumbs.collect(function(li) {
			li.addClassName('active');
			return true;
		    });
	    }

	    this.nextSlide();
	}
    });

/*--------------------------------------------------------------------------------
--------------------------------------------------------------------------------*/
function set_layout() {
    var image = $('prod_img');
    var content = $('content');
    var prices = $('prices');

    var offset = 0;
    $A([$('price_calc'), $('price_list')]).each(function(elem) {
	    var o = elem.offsetWidth + elem.offsetLeft;
	    if (o > offset)
		offset = o;
	});

    prices.style.minWidth = (offset + image.offsetWidth - prices.offsetLeft + 4) + 'px';

    var bottom = image.offsetTop + image.offsetHeight;
    var pos = $('static').offsetTop;
    $$('div#static div').each(function(div) {
	    if (pos < bottom)
		div.style.maxWidth = image.offsetLeft - div.offsetLeft - 20 + 'px';
	    pos += div.offsetHeight;
	});
}

var cycler = null;
Event.observe(window, "load", function() {
	var images = $('main_imgs');
	if (images)
	    cycler = new Protocycle(images, $$('ul.thumbs li'));
	
	set_layout();
    });

window.onresize = set_layout;

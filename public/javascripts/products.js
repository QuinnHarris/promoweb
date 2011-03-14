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




var prop_selected = []
var quantity = ''
var technique = ''
var decoration = ''

function id_parse(str) {
  var arr = str.split('-')
  return parseInt(arr[1])
}

function unselect(ul) {
  for (var i=0; i<ul.childNodes.length; i++)
    ul.childNodes[i].className = ''
}

var tech_limit
var tech_default = ''
var tech_value = ''
function apply_tech(li) {
  var ul = li.parentNode
  unselect(ul)
  li.className = 'sel' 

  for (var i=0; i < decorations.length; i++) {
    if (decorations[i][0] == technique) {
      var locations = decorations[i][3]
      tech_default = decorations[i][2]
      tech_value = tech_default
      var elems = []
      
      var ul = $('locations')
      var dd = ul.parentNode
      var dt = dd.previousSibling
      var display = "none"
       
      tech_limit = NaN
      if (locations.length > 0) {
        for (var j=0; j < locations.length; j += 3) {
          elems.push('<li id="dec-' + locations[j] + '"><a href="#" onclick="return sel_loc(this)"><span>' + locations[j+1] + '</span></a></li>')
          
          if (locations[j+2] && !(tech_limit > locations[j+2]))
            tech_limit = locations[j+2]          
        }
    
        ul.innerHTML = elems.join('')
        display = ''
      }

      dd.style.display = display
      dt.style.display = display
      
      var inp = $('unit_value')
      if (inp) {
        var dd = inp.parentNode
        var dt = dd.previousSibling
        
        if (decorations[i][1].length > 0) {
          dt.innerHTML = '<span>' + decorations[i][1] + '</span>'
          dt.style.display = ''
          dd.style.display = ''
          inp.value = tech_value || ''
        } else {
          dt.style.display = 'none'
          dd.style.display = 'none'
        }
      }

      break
    }
  }
}


function price_multiplier(params, value, mult) {
  var num = Math.floor((value - 1 - params[1]) / params[0])
  return num ? (num * mult) : 0
}


function price_proc(params, qty) {
  var cons = params[0]
  var exp = params[1]
  var marginal = params[2]
  
  return Math.round(marginal * (1 + cons * Math.pow(qty, exp)))
}

function price_tech(qty) {
  for (var i=0; i < decorations.length; i++)
    if (decorations[i][0] == technique) {
      var ret = [[2147483647,0],[2147483647,0]]
      var breaks = decorations[i][4]
      for (var j=breaks.length-1; j >= 0; j--) {
        if (!tech_value || breaks[j][0] <= tech_value) {
          var params = breaks[j]

          var min_fixed = params[1]
          var min_marginal = price_proc(params.slice(2,5), qty)
          
          var value = tech_value ? tech_value : tech_limit
          if (value > (breaks[j+1] || [])[0])
            value = breaks[j+1][0]
          
          var max_fixed = min_fixed
          var max_marginal = min_marginal
          if (value) {
            max_fixed += price_multiplier(params.slice(5,7), value, params[9])
            max_marginal += price_multiplier(params.slice(7,9), value, price_proc(params.slice(10,13), qty))
          }
          
          if (tech_value)
            return [[max_fixed, max_fixed], [max_marginal, max_marginal]]
            
          ret[0][0] = Math.min(ret[0][0], min_fixed)
          ret[0][1] = Math.max(ret[0][1], max_fixed)
          
          ret[1][0] = Math.min(ret[1][0], min_marginal)
          ret[1][1] = Math.max(ret[1][1], max_marginal)
        }
      }   
    
      return ret
    }
    
  return NaN
}




function sel_tech(a) {
  var li = a.parentNode
  
  technique = id_parse(li.id)
  setCookie('technique', technique)
    
  apply_tech(li)
  
  calc_prices()
  
  return false
}

function load_tech() {
  technique = parseInt(getCookie('technique'))
  var li
  if (technique)
    li = $('tech-' + technique)
	
  if (!li) {
    var techniques = $('techniques')
    if (techniques) {
      li = techniques.getElementsByClassName('sel')[0]
      technique = id_parse(li.id)
    } else
      technique = ''
  }
  
  if (technique != '')
    apply_tech(li)
}

function sel_loc(a) {
  var li = a.parentNode
  var ul = li.parentNode
  unselect(ul)
  li.className = 'sel' 
  
  decoration = id_parse(li.id)
  
  return false
}

function sel_opt(a) {
    var li = a.parentNode;
    var ul = li.parentNode;
    unselect(ul);
    li.className = 'sel';
  
    var grp_id = id_parse(ul.id);
    var prop_id = id_parse(li.id);
    prop_selected[grp_id] = prop_id;
  
    calc_prices();

    cycler.setVariants(a.parentNode.getAttribute('data-variants'));
}

function clear_opt(a) {
    var div = a.parentNode.parentNode;
    var ul = div.getElementsByTagName('ul')[0];
    unselect(ul);
  
    var grp_id = id_parse(ul.id);
    prop_selected[grp_id] = NaN;
  
    calc_prices();
  
    cycler.setVariants('');
}

function get_groups() {
  var sets = []
  
  if (prop_selected.length == 0)
    return prices
  
  for (var i = 0; i < prices.length; i++) {
    var entry = prices[i]
    var count = 0
    for (var j = 0; j < entry[4].length; j++) {
      var predicate = entry[4][j]
      var val = prop_selected[j]
      if (!val || (predicate.indexOf(val) != -1))
        count += 1
    }
    if (count == entry[4].length)
      sets.push(entry)
  }
  
  return sets
}

function calc_price(grp, n) {
  var id = grp[0]
  var connst = grp[1];
  var exp = grp[2];
  var fixed;
  var marginal;
  
  if (grp[3][0][0] > n)
    return [NaN, NaN];
  
  for (var i = 1; i < grp[3].length; i++)
    if (grp[3][i][0] > n) {
      fixed = grp[3][i-1][1];
      marginal = grp[3][i-1][2];
      break;
    }
    
  if (!marginal)
    return [2147483647,2147483647]
  
	return [0.0, Math.round(fixed/(n*10.0))*10 + Math.round((marginal + connst * Math.pow(n, exp))/10.0)*10];
}

function calc_prices() {
  var mymins = []
  var groups = get_groups()
  var elems 
  
  if (!quantity) {
     mymins = minimums
  } else if (quantity < minimums[0]) {      
    mymins = [quantity].concat(minimums.slice(0,4))
  } else if (quantity > minimums.last()) {
    mymins = minimums.slice(1, 5).concat([quantity])
  } else {
    mymins[0] = Math.round(quantity / 2)
    if (mymins[0] < minimums[0])
      mymins[0] = minimums[0]
    mymins[1] = Math.round((quantity + mymins[0]) / 2)
    mymins[2] = quantity
    mymins[4] = Math.round(quantity * 2)
    if (mymins[4] > minimums.last())
      mymins[4] = minimums.last()
    mymins[3] = Math.round((mymins[4] + quantity) / 2)

    var last = mymins[0]
    for (var i=1; i < mymins.length; i++)
      if (mymins[i] == last) {
        mymins.splice(i,1)
        i--
      } else
        last = mymins[i]
  }
  
  var trs = [$('setup_row'), $('price_row'), $('total_row'), $('qty_row')]

  for (var i = 0; i < mymins.length; i++) {
    var qty = mymins[i]   
    var min = []
    var max = []
    
    for (var j = 0; j < groups.length; j++) {
      var prices = calc_price(groups[j], qty)
      for (var k = 0; k < 2; k++) {
        min[k] = Math.min(min[k] || 2147483647, prices[k])
        max[k] = Math.max(max[k] || 0, prices[k])
      }
    }

    var prices = price_tech(qty)
    if (prices)
      for (var k = 0; k < 2; k++) {
        min[k] += prices[k][0]
        max[k] += prices[k][1]
      }
    
    min[2] = min[0] + min[1]*qty
    max[2] = max[0] + max[1]*qty
    
    trs[trs.length-1].childNodes[i+1].innerHTML = qty
    for (var j = 0; j < trs.length-1; j++)
      trs[j].childNodes[i+1].innerHTML = range_to_str(min[j],max[j])
    
    for (var j = 0; j < trs.length; j++) {
      child = trs[j].childNodes[i+1]
      child.setAttribute("class", (qty == quantity) ? "sel" : "")
      child.style.display = ''
    }
  }
  
  for (var i = mymins.length; i < trs[0].childNodes.length-1; i++)
    for (var j = 0; j < trs.length; j++)
      trs[j].childNodes[i+1].style.display = 'none'
}

function int_to_money(val) {
  var number = (val / 1000).toFixed(2);
  if (number.length > 6) {
    var mod = number.length % 3;
    var output = (mod > 0 ? (number.substring(0,mod)) : '');
    var max = Math.floor(number.length / 3)
    for (i=0 ; i < max; i++) {
      if (((mod == 0) && (i == 0)) || (i == max - 1))
        output += number.substring(mod+ 3 * i, mod + 3 * i + 3);
      else
        output+= ',' + number.substring(mod + 3 * i, mod + 3 * i + 3);
    }
    return '$' + output
  } else
    return '$' + number
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

function range_to_str(min, max) {
  if ((min || 0) == (max || 0))
    return num_to_str(min)
  else
    return num_to_str(min) + ' to ' +
           num_to_str(max)
  return NaN
}

function change_quantity() {
  var input = $('quantity').value
  quantity = parseInt(input)
  setCookie('quantity', quantity)
  calc_prices()
}

function change_units() {
  var input = $('unit_value').value
  tech_value = parseInt(input)
  if (tech_value > tech_limit) {
    tech_value = tech_limit
    $('unit_value').value = tech_value
  }
    
  calc_prices() 
}

function load_quantity() {
  quantity = parseInt(getCookie('quantity'))
  if (quantity)
    $('quantity').value = quantity
}

function image_change(event) {
    var main = $('main_img');
    var target = event.target;
    if (target.tagName == 'LI')
	target = $(target).down();
    main.src = target.src.replace('_thumb', '_medium')
}

function load_image() {
    var lis = $('prod_img').getElementsByTagName('li');
    for (var i = 0; i < lis.length; i++) {
	var li = lis[i];
	Event.observe(li, 'mouseover', image_change);
    }
}

function num_keypress(myfield, e, post_func) {
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
    
  if ((("0123456789").indexOf(keychar) > -1)) {
    if (myfield.value.length > 5)
      return false;
  } else if (!((key==null) || (key==0) || (key==8) ||
      (key==9) || (key==13) || (key==27)))
      return false;
  
  setTimeout(post_func, 0);
  
  return true;
}

function order_submit(form, pedantic) {
  var msg = []
  if (pedantic) {
    if (!(parseInt(quantity) > 0))
      msg.push('quantity (enter number to right of Quantity:)')
    else if (parseInt(quantity) < minimums[0])
      msg.push('quantity at ' + minimums[0] + ' minimum')
  }

  var groups = get_groups()
  if (groups.length != 1)
    msg.push('a variant (Click on the appropriate box under Variants heading)')
    
  if (msg.length != 0) {
    alert("Must specify " + msg.join(' and '))
    return false
  }

  form.price_group.value = groups[0][0]
  form.properties.value = prop_selected.join(',')
  form.quantity.value = quantity
  form.technique.value = technique
  form.decoration.value = decoration
  form.unit_count.value = tech_value
  return true
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
                timeout: 4000, // time between slide changes (in milliseconds)
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

	setVariants: function(string)
	{
	    var count = 0;
	    var variants = string.split(' ');
	    this.active = this.thumbs.collect(function(li) {
		    if (li.getAttribute('data-variants').split(' ').intersect(variants).length > 0) {
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
var cycler = null;
Event.observe(window, "load", function() {
        cycler = new Protocycle($('main_imgs'), $$('ul.thumbs li'));
    });
    
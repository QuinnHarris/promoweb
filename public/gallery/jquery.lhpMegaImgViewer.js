// Mega Image Viewer v2.0 - jQuery image viewer plugin - converting <div> element to an animated image viewer
// (c) 2012 lhp - http://codecanyon.net/user/lhp

/*
 * ----------------------------------------------------------------------------
 * settings:
 * viewportWidth 				string (default: '100%'; accepted: string; Defines width of the area in which image will be displayed inside the outer div (myDiv). Size can be given in pixels, ems, percentages.)
 * viewportHeight 				string (default: '100%'; accepted: string; Defines height of the area in which image will be displayed inside the outer div (myDiv). Size can be given in pixels, ems, percentages.)
 * fitToViewportShortSide		boolean (default: false; accepted: true, false; Shorter side of the displayed object will fit the viewport. )
 * contentSizeOver100 			boolean (default: false; accepted: true, false; If the viewport size (width and height) is greater than the size of the displayed object, allow the object scaled over 100% to fit the viewport (zoom is disabled). )
 * startScale 					number (default: 1; accepted: 0...1; Defines start scale.)
 * startX 						number (default: 0; accepted: integer; Defines start coordinate x in px, in the display object frame of reference, which will be moved to the center of the viewport, if it is possible.)
 * startY 						number (default: 0; accepted: integer; Defines start coordinate y in px, in the display object frame of reference, which will be moved to the center of the viewport, if it is possible.)
 * animTime 					number (default: 500; accepted: integer; Defines duration in ms of the scale and position animations.)
 * draggInertia 				number (default: 10; accepted: integer; Defines inertia after dragging.)
 * contentUrl 					string (default: ''; accepted: string; Defines a path for an image source. This param is optional. Instead you can use the HTML image tag (see DOC -> STEP 2B - ACTIVATE THE PLUGIN (IMAGE SOURCE FROM HTML)).)
 * intNavEnable 				boolean (default: true; accepted: true, false; Defines the navigation bar enabled/disabled. )
 * intNavPos 					string (default: 'T'; accepted: 'TL', 'T', 'TR', 'L', 'R', 'BL', 'B', 'BR'; Defines the navigation bar position. )
 * intNavAutoHide 				boolean (default: false; accepted: true, false; Defines the navigation bar autohide. )
 * intNavMoveDownBtt			boolean (default: true; accepted: true, false; Defines button visibility 'move down' on the navigation bar. )
 * intNavMoveUpBtt				boolean (default: true; accepted: true, false; Defines button visibility 'move up' on the navigation bar. )
 * intNavMoveRightBtt			boolean (default: true; accepted: true, false; Defines button visibility 'move right' on the navigation bar. )
 * intNavMoveLeftBtt			boolean (default: true; accepted: true, false; Defines button visibility 'move left' on the navigation bar. )
 * intNavZoomBtt				boolean (default: true; accepted: true, false; Defines button visibility 'zoom' on the navigation bar. )
 * intNavUnzoomBtt				boolean (default: true; accepted: true, false; Defines button visibility 'unzoom' on the navigation bar. )
 * intNavFitToViewportBtt		boolean (default: true; accepted: true, false; Defines button visibility 'fit to viewport' on the navigation bar. )
 * intNavFullSizeBtt			boolean (default: true; accepted: true, false; Defines button visibility 'full size' on the navigation bar. )
 * mapEnable					boolean (default: true; accepted: true, false; Displays the map palette to quickly change the view using a thumbnails. )
 * mapThumb						string (default: null; accepted: string; Defines a path for an thumbnail source used in map palette. )
 * mapPos						string (default: 'BL'; accepted: 'TL', 'T', 'TR', 'L', 'R', 'BL', 'B', 'BR'; Defines the map palette position. )
 * popupShowAction				string (default: 'rollover'; accepted: 'click', 'rollover'; Defines 'popup' window opening action. )
 * testMode						boolean (default: false; accepted: true, false; Displays coordinates of the cursor. )
 * ----------------------------------------------------------------------------
 */
 
(function ($) {
	
	var pubMet, constSett, defaultSett;
	
	constSett = {
		'dragSmooth' : 8
	};
	
	defaultSett = {
		'viewportWidth' : '100%',
		'viewportHeight' : '100%',
		'fitToViewportShortSide' : false,  
		'contentSizeOver100' : false,
		'startScale' : 1,
		'startX' : 0,
		'startY' : 0,
		'animTime' : 500,
		'draggInertia' : 10,
		'contentUrl' : '',
		'intNavEnable' : true,
		'intNavPos' : 'T',
		'intNavAutoHide' : false,
		'intNavMoveDownBtt' : true,
		'intNavMoveUpBtt' : true,
		'intNavMoveRightBtt' : true,
		'intNavMoveLeftBtt' : true,
		'intNavZoomBtt' : true,
		'intNavUnzoomBtt' : true,
		'intNavFitToViewportBtt' : true,
		'intNavFullSizeBtt' : true,
		'mapEnable' : true,
		'mapThumb' : null,
		'mapPos' : 'BL',
		'popupShowAction' : 'rollover',
		'testMode' : false
	};

	pubMet = {
		init : function (options, markersContainer) {
			
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV'), interImgs = $t.find('img'), sett = {};
				$.extend(sett, defaultSett, options);
				$.extend(sett, constSett);
				
				if (!data) {
					
					if(sett.draggInertia < 0) {
						sett.draggInertia = 0;
					}
					
					sett.animTime = parseInt(sett.animTime);
					if(sett.animTime < 0) {
						sett.animTime = 0;
					}
					
					/*img tag*/
					if(interImgs.length > 0) {
						sett.contentUrl = interImgs[0].src;
						interImgs.remove();
					}
					
					$t.data('lhpMIV', {});
					$t.data('lhpMIV').interImgsTmp = interImgs;
					$t.data('lhpMIV').lc = new LocationChanger(sett, $t, markersContainer);
				}
			});
		},
		/*
		* Sets the position and size of the displayed object. The second parameter is optional - if empty, the size remains unchanged.
		* @param {integer} x Coordinate x in px, in the display object frame of reference, which will be moved to the center of the viewport (if it is possible).
		* @param {integer} y Coordinate y in px, in the display object frame of reference, which will be moved to the center of the viewport (if it is possible).
		* @param {number} scale The size to which the display object will be scaled (if it is possible); optional.
		* @param {boolean} noAnim Animations disabled; optional.
		* @return {Object} Returns jQuery object.
		*/
		setPosition : function (x, y, scale, noAnim) {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.setProperties(x, y, scale, noAnim);
				}
			});
		},
		/*
		* Initializes the movement of the display object to the top, to the boundary of the viewport or untill the moveStop method is called.
		* @return {Object} Returns jQuery object.
		*/
		moveUp : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.beginDirectMove('U');
				}
			});
		},
		/*
		* Initializes the movement of the display object to the bottom, to the boundary of the viewport or untill the moveStop method is called.
		* @return {Object} Returns jQuery object.
		*/
		moveDown : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.beginDirectMove('D');
				}
			});
		},
		/*
		* Initializes the movement of the display object to the left, to the boundary of the viewport or untill the moveStop method is called.
		* @return {Object} Returns jQuery object.
		*/
		moveLeft : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.beginDirectMove('L');
				}
			});
		},
		/*
		* Initializes the movement of the display object to the right, to the boundary of the viewport or untill the moveStop method is called.
		* @return {Object} Returns jQuery object.
		*/
		moveRight : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.beginDirectMove('R');
				}
			});
		},
		/*
		* Stops the movement of the display object.
		* @return {Object} Returns jQuery object.
		*/
		moveStop : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.stopDirectMoving();
				}
			});
		},
		/*
		* Initializes the zooming of the display object up to 100% or untill the zoomStop method is called.
		* @return {Object} Returns jQuery object.
		*/
		zoom : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.beginZooming('Z');
				}
			});
		},
		/*
		* Initializes the unzooming of the display object up to the viewport's size or untill the zoomStop method is called.
		* @return {Object} Returns jQuery object.
		*/
		unzoom : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.beginZooming('U');
				}
			});
		},
		/*
		* Stops the zooming/unzooming of the display object.
		* @return {Object} Returns jQuery object.
		*/
		zoomStop : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.stopZooming();
				}
			});
		},
		/*
		* Fits the display obejct's size to the viewport size and moves the object to the center of the viewport.
		* @return {Object} Returns jQuery object.
		*/
		fitToViewport : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.setProperties(null, null, 0);
				}
			});
		},
		/*
		* Sets the initial size of the display object and moves the object to the center of the viewport.
		* @return {Object} Returns jQuery object.
		*/
		fullSize : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.setProperties(null, null, 1);
				}
			});
		},
		/*
		* Control the correct position and size of the object displayed inside the viewport.
		* @return {Object} Returns jQuery object.
		*/
		adaptsToContainer : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.adaptsToContainer();
				}
			});
		},
		/*
		* ...
		* @return {Object} Returns object with control values. The object is identical as the object returned by the event 'mivChange'.
		*/
		getCurrentState : function () {
			var $t = $(this), data = $t.data('lhpMIV'), res = {};
			if (data) {
				res = $t.data('lhpMIV').lc.getCurrentState();
			}
			return res;
		},
		/*
		* Destructor. Removes the viewer from the page. Restores the original appearance and functionality of the outer <div> element. Allows to efficiently clean the memory.
		* @return {Object} Returns jQuery object.
		*/
		destroy : function () {
			return this.each(function () {
				var $t = $(this), data = $t.data('lhpMIV');
				if (data) {
					$t.data('lhpMIV').lc.destroy();
					$t.prepend($t.data('lhpMIV').interImgsTmp);
					$t.removeData('lhpMIV');
				}
			});
		}
	};
	
	$.fn.lhpMegaImgViewer = function (method) {
		if (pubMet[method]) {
			return pubMet[method].apply(this, Array.prototype.slice.call(arguments, 1));
		} else if (typeof method === 'object' || !method) {
			return pubMet.init.apply(this, arguments);
		} else {
			$.error('Method ' +  method + ' does not exist on jQuery.lhpMegaImgViewer');
		}
	};
	
	/*location changer*/
	var LocationChanger = function (sett, $mainHolder, markersContainer) {
		this.isTouchDev = (typeof(window.ontouchstart) != 'undefined') ? true : false;
		this.sett = sett;
		this.$mainHolder = $mainHolder;
		this.lastMousePageCoor = null;
		this.lastDrag = null;
		this.contentFullSize = {};
		this.$mivHol = null;
		this.$contentHol = null;
		this.$content = null;
		this.$preloadHol = null; 
		this.$blackScreen = null;
		this.$infoBox = null;
		this.$navHol = null;
		this.movingIntreval = null;
		this.movingDirectIntreval = null;
		this.navAutohideInterval = null;
		this.speedX = this.speedY = null;
		this.targetX = this.targetY = null;
		this.allow = {allowDown : false, allowUp : false, allowLeft : false, allowRight : false, allowZoom : false, allowUnzoom : false};
		this.isScaled = false;
		this.sm = new ScaleManager();
		this.map = null;
		
		/*markers*/
		this.markersContainer = markersContainer;
		this.markers = null;

		this.createHolders();
		
		/*load content*/
		this.contentLoader = new LoaderImgContent(this.sett.contentUrl, this.$contentHol, function(that) { 
			return function($content) {
				that.imgContentStart($content);
			}
		}(this));
		this.contentLoader.loadStart();
		/**/
	};
	//initialization
	LocationChanger.prototype.createHolders = function () {
		this.$mivHol = $('<div />')
		.addClass('lhp_miv_holder')
		.css({position : 'relative', overflow : 'hidden', width : this.sett.viewportWidth, height : this.sett.viewportHeight});
		
		this.$preloadHol = $('<div />')
		.addClass('lhp_miv_preload_holder');
		
		this.$contentHol = $('<div />')
		.addClass('lhp_miv_content_holder')
		.css({position : 'absolute'});
		
		this.$blackScreen = $('<div />')
		.addClass('lhp_miv_blackScreen')
		.css({position : 'absolute', 'z-index' : '9999', width : '100%', height : '100%', background : '#ffffff'});

		this.$mivHol.append(this.$preloadHol);
		this.$mivHol.append(this.$blackScreen);
		this.$mivHol.append(this.$contentHol);
		this.$mainHolder.append(this.$mivHol);
		
		if(this.sett.testMode) {
			this.$infoBox = $('<div />').addClass('lhp_miv_infoBox_holder');
			this.$mivHol.append(this.$infoBox);
		}
	}
	LocationChanger.prototype.iniNav = function () {
		var $ul = $('<ul />').addClass('ui-widget ui-helper-clearfix'),
		$mainHolder = this.$mainHolder,
		$navHol = this.$navHol,
		$li, $span,
		_this = this,
		navBttW = 27,
		navHolW = 0,
		btt = [['moveDown', 'moveStop', 'ui-icon-carat-1-n', 'intNavMoveDownBtt'], 
			['moveUp', 'moveStop', 'ui-icon-carat-1-s', 'intNavMoveUpBtt'], 
			['moveRight', 'moveStop', 'ui-icon-carat-1-w', 'intNavMoveRightBtt'], 
			['moveLeft', 'moveStop', 'ui-icon-carat-1-e', 'intNavMoveLeftBtt'],
			['zoom', 'zoomStop', 'ui-icon-zoomin', 'intNavZoomBtt'], 
			['unzoom', 'zoomStop', 'ui-icon-zoomout', 'intNavUnzoomBtt'], 
			['fitToViewport', null, 'ui-icon-stop', 'intNavFitToViewportBtt'], 
			['fullSize', null, 'ui-icon-arrow-4-diag', 'intNavFullSizeBtt']];
			
		$.each(btt, function(i) {
			var mousedownFunc = btt[i][0],
			mouseupFunc = btt[i][1],
			settName = btt[i][3],
			$li, $span;
			
			if(_this.sett[settName]) {
				navHolW += navBttW;

				$li = $('<li />').addClass('ui-state-default ui-corner-all ' + mousedownFunc),
				$span = $('<span />').addClass('ui-icon ' + btt[i][2])
				$li.append($span);
				$ul.append($li);

				$li.bind('mouseenter.lhpMIV touchstart.lhpMIV', function() { 
					if(!$(this).hasClass('lhp_miv_nav_btt_disab')) {
						$(this).addClass('ui-state-hover');
					}
				});

				$li.bind('mouseleave.lhpMIV touchend.lhpMIV', function() { 
					$(this).removeClass('ui-state-hover');
				});
				
				$li.bind( ((_this.isTouchDev) ? 'touchstart.lhpMIV' : 'mousedown.lhpMIV'), function(func) { 
					return function(e) { 
						if(!$(this).hasClass('lhp_miv_nav_btt_disab')) {
							$mainHolder.lhpMegaImgViewer(func);
						}
						e.preventDefault();
					} 
				}(mousedownFunc));

				if(mouseupFunc) {
					$li.bind( ((_this.isTouchDev) ? 'touchend.lhpMIV' : 'mouseup.lhpMIV'), function(func) { 
						return function(e) { 
							if(!$(this).hasClass('lhp_miv_nav_btt_disab')) {
								$mainHolder.lhpMegaImgViewer(func);
							}
							e.preventDefault();
						} 
					}(mouseupFunc));
				}
			}
			
		});
		
		/*position*/
		if(this.$navHol.hasClass('lhp_miv_nav_pos_L') || this.$navHol.hasClass('lhp_miv_nav_pos_R')) {
			this.$navHol.css('width', navBttW);
			this.$navHol.css('margin-top', -navHolW/2); 
		}
		if(this.$navHol.hasClass('lhp_miv_nav_pos_T') || this.$navHol.hasClass('lhp_miv_nav_pos_B')) {
			this.$navHol.css('margin-left', -navHolW/2); 
		}

		$mainHolder.bind('mivChange.lhpMIV', function(e) {
			
			var c1 = 'lhp_miv_nav_btt_disab', c2 = 'ui-state-hover';

			if(e.allowDown) {
				$navHol.find('.moveDown').removeClass(c1);
			} else {
				$navHol.find('.moveDown').removeClass(c2).addClass(c1);
			}
			
			if(e.allowUp) {
				$navHol.find('.moveUp').removeClass(c1);
			} else {
				$navHol.find('.moveUp').removeClass(c2).addClass(c1);
			}
			
			if(e.allowLeft) {
				$navHol.find('.moveLeft').removeClass(c1);
			} else {
				$navHol.find('.moveLeft').removeClass(c2).addClass(c1);
			}
			
			if(e.allowRight) {
				$navHol.find('.moveRight').removeClass(c1);
			} else {
				$navHol.find('.moveRight').removeClass(c2).addClass(c1);
			}
			
			if(e.allowZoom) {
				$navHol.find('.zoom').removeClass(c1);
				$navHol.find('.fullSize').removeClass(c1);
			} else {
				$navHol.find('.zoom').removeClass(c2).addClass(c1);
				$navHol.find('.fullSize').removeClass(c2).addClass(c1);
			}
			
			if(e.allowUnzoom) {
				$navHol.find('.unzoom').removeClass(c1);
				$navHol.find('.fitToViewport').removeClass(c1);
			} else {
				$navHol.find('.unzoom').removeClass(c2).addClass(c1);
				$navHol.find('.fitToViewport').removeClass(c2).addClass(c1);
			}

		});
		
		if(this.sett.intNavAutoHide) {
			$navHol.css('display', 'none');
			$mainHolder.bind('mouseenter.lhpMIV touchstart.lhpMIV', function() { 
				clearInterval(_this.navAutohideInterval);
				$navHol.fadeIn('fast'); 
			});
			$mainHolder.bind('mouseleave.lhpMIV touchend.lhpMIV', function() { 
				clearInterval(_this.navAutohideInterval);
				_this.navAutohideInterval = setInterval(function($navHol){
					return function () {
						$navHol.stop().clearQueue().fadeOut('fast');
					};
				}($navHol), 1000);
			});
		}
		
		$navHol.append($ul);
	}
	LocationChanger.prototype.imgContentStart = function ($content) {
		this.$content = $content;
		$content.addClass('lhp_miv_content').css({'float' : 'left'});
		
		this.contentFullSize = {'w' : $content.width(), 'h' : $content.height()};
		this.sett.mainImgWidth = this.contentFullSize.w;
		this.sett.mainImgHeight = this.contentFullSize.h;
		
		this.start();
		this.$preloadHol.remove();
		this.$blackScreen.animate({ opacity : 0 }, { duration : 500, complete : function(){ $(this).remove(); }});
	}
	LocationChanger.prototype.start = function () {
		
		if(this.sett.mapEnable && this.sett.mapThumb) {
			this.map = new Map(this.sett, this.$mainHolder, this.$content, this.isTouchDev);
			this.map.ini(this.$mivHol);
		}
		
		if(this.sett.intNavEnable) {
			this.$navHol = $('<div class="lhp_miv_nav"/>').addClass('lhp_miv_nav_pos_' + this.sett.intNavPos);
			this.iniNav();
			this.$mivHol.prepend(this.$navHol);
		}
		
		this.markers = new Markers(this.$mainHolder, this.$contentHol, this.markersContainer, this.isTouchDev, this.sett.popupShowAction, this.sett.startScale);
		this.markers.ini();
		
		this.$contentHol.bind('mouseenter.lhpMIV', {'_this' : this}, this.mouseenterHandler);
		if(this.isTouchDev) {
			this.$contentHol.bind('touchstart.lhpMIV', {'_this' : this}, this.mousedownHandler);
		} else {
			this.$contentHol.bind('mousedown.lhpMIV', {'_this' : this}, this.mousedownHandler);
			this.$contentHol.bind('mouseup.lhpMIV', {'_this' : this}, this.mouseupHandler);
			this.$contentHol.bind('mouseleave.lhpMIV', {'_this' : this}, this.mouseupHandler);
		}
		this.$contentHol.bind('mousewheel.lhpMIV', {'_this' : this}, this.mousewheelHandler);
		
		if(this.sett.testMode) {
			this.$contentHol.bind('mousemove.lhpMIV', {'_this' : this}, this.showCurrentCoor);
		}
		
		this.setProperties(this.sett.startX, this.sett.startY, this.sett.startScale, true);
	}	
	LocationChanger.prototype.destroy = function () {
		/*clear content*/
		this.contentLoader.dispose();
		this.contentLoader = null;
		
		/*clear callback*/
		this.animStop();
		this.stopMoving();
		this.stopDirectMoving();
		
		/*destroy markers*/
		if(this.markers) {
			this.markers.destroy();
		}
		
		/*clear nav handler*/
		if(this.$navHol) {
			this.$navHol.find('li').each(function(i) {
				$(this).unbind();
			});
		}
		
		/*destroy map*/
		if(this.map) {
			this.map.destroy();
		}

		/*clear handler*/
		this.$mainHolder.unbind('.lhpMIV');
		this.$contentHol.unbind();
		
		/*clear holders*/
		this.$mivHol.remove();

		/*clear properties*/
		$.each(this, function(k, v) {
			if(!$.isFunction(v)) {
				k = null;
			}
		});
	}
	//mouse handlers
	LocationChanger.prototype.mousePageCoor = function (e) {
		var r = {x : e.pageX, y : e.pageY};
		e = e.originalEvent;
		if(this.isTouchDev && e) {
			r.x = e.changedTouches[0].pageX; 
			r.y = e.changedTouches[0].pageY;
		}
		return r;
	}
	LocationChanger.prototype.mouseenterHandler = function (e) {
		if(!e.data._this.sett.testMode) e.data._this.$contentHol.css('cursor', 'url(/gallery/lhp_miv/cursorHand.png),default');
	}
	LocationChanger.prototype.mousedownHandler = function (e) {
		var _this = e.data._this;
		
		_this.animStop(true);
		_this.stopMoving();
		_this.stopDirectMoving();
		
		if(_this.isTouchDev) {
			_this.$contentHol.unbind('touchmove.lhpMIV', _this.mousemoveHandler).bind('touchmove.lhpMIV', {'_this' : _this}, _this.mousemoveHandler);
			_this.$contentHol.unbind({'touchend.lhpMIV' : _this.positioning}).bind('touchend.lhpMIV' , {'_this' : _this}, _this.positioning);
		} else {
			_this.$contentHol.unbind('mousemove.lhpMIV', _this.mousemoveHandler).bind('mousemove.lhpMIV', {'_this' : _this}, _this.mousemoveHandler);
			_this.$contentHol.unbind({'mouseup.lhpMIV' : _this.positioning}).bind('mouseup.lhpMIV' , {'_this' : _this}, _this.positioning);
		}
		
		_this.lastMousePageCoor = _this.mousePageCoor(e);
		_this.$contentHol.css('cursor', 'url(css/lhp_miv/cursorDrag.png), move');
		e.preventDefault();
	}
	LocationChanger.prototype.mousemoveHandler = function (e) {
		var _this = e.data._this;

		if(_this.isTouchDev) {
			_this.$contentHol.unbind({'touchend.lhpMIV' : _this.positioning});
			_this.$contentHol.unbind({'touchend.lhpMIV' : _this.stopDraggingHandler}).bind('touchend.lhpMIV' , {'_this' : _this}, _this.stopDraggingHandler);
		} else {
			_this.$contentHol.unbind('mouseup.lhpMIV', _this.positioning);
			_this.$contentHol.unbind({'mouseup.lhpMIV' : _this.stopDraggingHandler}).bind('mouseup.lhpMIV' , {'_this' : _this}, _this.stopDraggingHandler);
			_this.$contentHol.unbind({'mouseleave.lhpMIV' : _this.stopDraggingHandler}).bind('mouseleave.lhpMIV' , {'_this' : _this}, _this.stopDraggingHandler);
		}

		_this.dragging(e, 'hard');
		e.preventDefault();
	}
	LocationChanger.prototype.mouseupHandler = function (e) {
		var _this = e.data._this;
		_this.$contentHol.unbind('mousemove.lhpMIV', _this.mousemoveHandler);
		_this.$contentHol.unbind('mouseup.lhpMIV', _this.positioning);
		
		if(!_this.sett.testMode) {
			_this.$contentHol.css('cursor', 'url(//gallery/lhp_miv/cursorHand.png),default');
		} else {
			_this.$contentHol.css('cursor', 'default');
		}
	}
	LocationChanger.prototype.stopDraggingHandler = function (e) {
		var _this = e.data._this;
		_this.$contentHol.unbind({'mouseup.lhpMIV' : _this.stopDraggingHandler});
		_this.$contentHol.unbind({'mouseleave.lhpMIV' : _this.stopDraggingHandler});
		_this.dragging(e, 'inertia');
	}
	LocationChanger.prototype.mousewheelHandler = function (e, delta) {
		var _this = e.data._this,
		newScale = (delta > 0) ? _this.sm.nextScale() : _this.sm.prevScale(),
		newProp = _this.calculateScale(e, newScale);
		
		_this.animStop();
		_this.stopMoving();
		_this.stopDirectMoving();
		_this.animSizeAndPos(newProp.x, newProp.y, newProp.w, newProp.h);
		e.preventDefault();
		return false;
	}
	LocationChanger.prototype.showCurrentCoor = function (e) {
		var _this = e.data._this,
		mousePageCoor = _this.mousePageCoor(e),
		contentHolPos = _this.$contentHol.position(),
		mivHolOff = _this.$mivHol.offset(),
		iterimScale =  _this.$content.width() / _this.contentFullSize.w;

		mousePageCoor.x = Math.round((mousePageCoor.x - contentHolPos.left - mivHolOff.left) / iterimScale);
		mousePageCoor.y = Math.round((mousePageCoor.y - contentHolPos.top - mivHolOff.top) / iterimScale);

		_this.$infoBox.css('display', 'block');
		_this.$infoBox.html('x:' + mousePageCoor.x + ' y:' + mousePageCoor.y);
	}
	//changers
	LocationChanger.prototype.adaptsToContainer = function () {
		if(this.$content) {
			var iterimScale =  this.$content.width() / this.contentFullSize.w;
			iterimScale = (iterimScale > 1) ? 1 : iterimScale;
			
			this.animStop();
			this.stopMoving();
			this.stopDirectMoving();
			this.setProperties(null, null, iterimScale, true);
		}
	}
	LocationChanger.prototype.beginZooming = function (t) {
		
		if(this.$content) {
		
			var delta = (t == 'Z') ? 1 : -1,
			data = {_this : this},
			mivCenter = {'x' : (this.$mivHol.width() / 2), 'y' : (this.$mivHol.height() / 2)},
			mivHolOff = this.$mivHol.offset(),
			mouseMivCenter = {'x' : (mivCenter.x + mivHolOff.left), 'y' : (mivCenter.y + mivHolOff.top)},
			e = {data : data, pageX : mouseMivCenter.x, pageY : mouseMivCenter.y }; //pseudo event object

			this.animStop(true);
			this.stopMoving();
			this.stopDirectMoving();

			if(!this.movingIntreval) {
				this.movingIntreval = setInterval(function(_this, e, delta){
						return function () {
							_this.zooming(e, delta);
						};
				}(this, e, delta), this.sett.animTime / 5);
			}

			this.zooming(e, delta);
		} 
	}
	LocationChanger.prototype.zooming = function (e, delta) {
		var newScale = (delta > 0) ? this.sm.nextScale() : this.sm.prevScale(),
		newProp = this.calculateScale(e, newScale);
		
		this.animStop();
		this.animSizeAndPos(newProp.x, newProp.y, newProp.w, newProp.h);
		
		if(this.sett.fitToViewportShortSide) {
			if(newScale >= 1 || newProp.w <= this.$mivHol.width() || newProp.h <= this.$mivHol.height()) {
				this.stopZooming();
			}
		} else {
			if(newScale >= 1 || (newProp.w <= this.$mivHol.width() && newProp.h <= this.$mivHol.height())) {
				this.stopZooming();
			}
		}
	}
	LocationChanger.prototype.stopZooming = function () {
		this.stopMoving();
	}
	LocationChanger.prototype.beginDirectMove = function (direct) {
		
		if(this.$content) {
			
			this.animStop(true);
			this.stopMoving();
			this.sm.setScale(this.$content.width() / this.contentFullSize.w);
			this.speedX = this.speedY = 0;

			switch(direct) {
				case 'U':
					this.speedY = -50000 / this.sett.animTime;
					break;
				case 'D':
					this.speedY = 50000 / this.sett.animTime;
					break;
				case 'L':
					this.speedX = -50000 / this.sett.animTime;
					break;
				case 'R':
					this.speedX = 50000 / this.sett.animTime;
					break;
			}

			if(!this.movingDirectIntreval && (this.speedX || this.speedY)) {
				this.movingDirectIntreval = setInterval(function(_this){
						return function () {
							_this.directMoveWithInertia();
						};
				}(this), 10);
			}
		} 
	}
	LocationChanger.prototype.directMoveWithInertia = function () {
		var holLeft = this.$contentHol.position().left,
		holTop = this.$contentHol.position().top,
		targetX = Math.ceil(holLeft + this.speedX),
		targetY = Math.ceil(holTop + this.speedY),
                safeTarget;
		
		if(!this.movingIntreval) {
			this.movingIntreval = setInterval(function(_this){
					return function () {
						_this.moveWithInertia();
					};
			}(this), 10);
		}
		
		safeTarget = this.getSafeTarget(targetX, targetY, this.speedX, this.speedY);
		
		this.targetX = Math.round(safeTarget.x); 
		this.targetY = Math.round(safeTarget.y);
	}
	LocationChanger.prototype.stopDirectMoving = function () {
		clearInterval(this.movingDirectIntreval);
		this.movingDirectIntreval = null;
	}
	LocationChanger.prototype.dragging = function (e, type) {
		var draggIner = this.sett.draggInertia,
		mousePageCoor = this.mousePageCoor(e),
		draggShftX = mousePageCoor.x - this.lastMousePageCoor.x,
		draggShftY = mousePageCoor.y - this.lastMousePageCoor.y;
		
		if(type == 'inertia' && this.lastDragg) {
			this.draggingWithInertia(this.lastDragg.x * draggIner, this.lastDragg.y * draggIner);
		} else {
			this.draggingHard(draggShftX, draggShftY);
		}
		
		this.lastDragg = {x : (Math.abs(draggShftX) < 5) ? 0 : draggShftX, 
						   y : (Math.abs(draggShftY) < 5) ? 0 : draggShftY};
		
		this.lastMousePageCoor = mousePageCoor;
	}
	LocationChanger.prototype.draggingHard = function (draggShftX, draggShftY) {
		var contentHolPos = this.$contentHol.position(),
		targetX = contentHolPos.left + draggShftX,
		targetY = contentHolPos.top + draggShftY,
		safeTarget = this.getSafeTarget(targetX, targetY, draggShftX, draggShftY);
		
		this.animStop();
		this.$contentHol.css({'left' : safeTarget.x, 'top' : safeTarget.y});
	}
	LocationChanger.prototype.draggingWithInertia = function (draggShftX, draggShftY) {
		var targetX = this.targetX + draggShftX,
		targetY = this.targetY + draggShftY,
		safeTarget;
		
		if(!this.movingIntreval) {
			this.movingIntreval = setInterval(function(_this){
					return function () {
						_this.moveWithInertia();
					};
			}(this), 10);
			targetX = this.$contentHol.position().left + draggShftX;
			targetY = this.$contentHol.position().top + draggShftY;
		}
		
		safeTarget = this.getSafeTarget(targetX, targetY, draggShftX, draggShftY);
		
		this.targetX = Math.round(safeTarget.x); 
		this.targetY = Math.round(safeTarget.y);
	}
	LocationChanger.prototype.getSafeTarget = function (targetX, targetY, moveDirectX, moveDirectY) {
		var limits = this.getLimit(this.sm.getScale()),
		xMin = limits.xMin,
		xMax = limits.xMax,
		yMin = limits.yMin,
		yMax = limits.yMax,
		mivHolW = this.$mivHol.width(),
		mivHolH = this.$mivHol.height(),
		mivHolCentX = mivHolW/2,
		mivHolCentY = mivHolH/2,
		newContentW = this.contentFullSize.w * this.sm.getScale(),
		newContentH = this.contentFullSize.h * this.sm.getScale();
		
		/*Y*/
		if((moveDirectY < 0) && (targetY < yMin)) { //move up limit
			targetY = yMin;
		} else if((moveDirectY > 0) && (targetY > yMax)) { // move down limit
			targetY = yMax;
		}
		
		if (newContentH < mivHolH)
		{
			targetY = mivHolCentY - newContentH / 2;
		}
		
		/*X*/
		if((moveDirectX < 0) && (targetX < xMin)) { //move left limit
			targetX = xMin;
		} else if((moveDirectX > 0) && (targetX > xMax)) { //move right limit 
			targetX = xMax;
		}
		
		if (newContentW < mivHolW)
		{
			targetX = mivHolCentX - newContentW / 2;
		}
		
		return {x : targetX, y : targetY};
	}
	LocationChanger.prototype.moveWithInertia = function () {
		var contentHolPos = this.$contentHol.position(),
		damping = this.sett.dragSmooth,
		distX, distY;
		
		contentHolPos.left = Math.ceil(contentHolPos.left);
		contentHolPos.top = Math.ceil(contentHolPos.top);
		distX = (this.targetX - contentHolPos.left)/damping;
		distY = (this.targetY - contentHolPos.top)/damping;
		
		if(Math.abs(distX) < 1) {
			distX = (distX > 0) ? 1 : -1
		}
		
		if(Math.abs(distY) < 1) {
			distY = (distY > 0) ? 1 : -1
		}
		
		if(contentHolPos.left == this.targetX) {
			distX = 0;
		}
		
		if(contentHolPos.top == this.targetY) {
			distY = 0;
		}
		
		this.$contentHol.css({'left' : contentHolPos.left + distX, 'top' : contentHolPos.top + distY});
		this.dispatchEventChange();
		
		if(contentHolPos.left == this.targetX && contentHolPos.top == this.targetY) {
			this.stopDirectMoving();
			this.stopMoving();
		}
	}
	LocationChanger.prototype.stopMoving = function () {
		clearInterval(this.movingIntreval);
		this.movingIntreval = null;
	}
	LocationChanger.prototype.positioning = function (e) {
		var _this = e.data._this, 
		newProp = _this.calculatePosInCenter(e);
		
		_this.animStop();
		_this.stopMoving();
		_this.stopDirectMoving();
		_this.animSizeAndPos(newProp.x, newProp.y);
	}
	LocationChanger.prototype.setProperties = function (x, y, scale, noAnim) {
		if(this.$content) {
			var data = {_this : this},
			mivCenter = {'x' : (this.$mivHol.width() / 2), 'y' : (this.$mivHol.height() / 2)},
			mivHolOff = this.$mivHol.offset(),
			mouseMivCenter = {'x' : (mivCenter.x + mivHolOff.left), 'y' : (mivCenter.y + mivHolOff.top)},
			e = {data : data, pageX : mouseMivCenter.x, pageY : mouseMivCenter.y }, //pseudo event object
			contentHolPos = this.$contentHol.position(),
			newProp, iterimScale,
			newX = contentHolPos.left, newY = contentHolPos.top, newW = this.$content.width(), newH = this.$content.height();
			
			x = parseFloat(x); 
			y = parseFloat(y); 
			scale = parseFloat(scale);
			
			if(!isNaN(scale)) {
				if(scale > 1) {
					scale = 1;
				}
				newProp = this.calculateScale(e, scale);
				newX = newProp.x;
				newY = newProp.y;
				newW = newProp.w;
				newH = newProp.h;
			}
			
			iterimScale =  newW / this.contentFullSize.w;
			
			if(!isNaN(x)) {
				newX = -(x * iterimScale) + mivCenter.x;
			}
			
			if(!isNaN(y)) {
				newY = -(y * iterimScale) + mivCenter.y;
			}
			
			this.animStop();
			this.stopMoving();
			this.stopDirectMoving();
			this.animSizeAndPos(newX, newY, newW, newH, noAnim);
		}
	}
	LocationChanger.prototype.calculatePosInCenter = function (e) {
		var contentHolPos = this.$contentHol.position(),
		mivHolOff = this.$mivHol.offset(),
		mivCenter = {'x' : (this.$mivHol.width() / 2), 'y' : (this.$mivHol.height() / 2)},
		mousePageCoor = this.mousePageCoor(e),
		mouseHolCoor = {'x' : (mousePageCoor.x - mivHolOff.left), 'y' : (mousePageCoor.y - mivHolOff.top)},
		shftX, shftY,
		newX, newY;
		
		shftX = mivCenter.x - mouseHolCoor.x;
		shftY = mivCenter.y - mouseHolCoor.y;
		newX = contentHolPos.left + shftX;
		newY = contentHolPos.top + shftY;
		
		return {x : newX, y : newY, 'shftX' : shftX, 'shftY' : shftY};
	}
	LocationChanger.prototype.calculateScale = function (e, newScale) {
		var mivHolOff = this.$mivHol.offset(),
		contentOff = this.$content.offset(),
		mousePageCoor = this.mousePageCoor(e), 
		iterimScale,
		mouseContentCoor,
		newX, newY, newW, newH;
		
		newScale = this.getSafeScale(newScale);
		this.sm.setScale(newScale);
		iterimScale =  this.$content.width() / this.contentFullSize.w;
		
		mouseContentCoor = {'x' : (mousePageCoor.x - contentOff.left) / iterimScale,
							'y' : (mousePageCoor.y - contentOff.top) / iterimScale};
							
		newW = Math.round(this.contentFullSize.w * newScale);
		newH = Math.round(this.contentFullSize.h * newScale);
		newX = Math.round(contentOff.left - mivHolOff.left + mouseContentCoor.x * (iterimScale - newScale));
		newY = Math.round(contentOff.top - mivHolOff.top + mouseContentCoor.y * (iterimScale - newScale));
		
		return {x : newX, y : newY, w : newW, h : newH};
	}
	LocationChanger.prototype.getSafeScale = function (newScale) {
		var safeScale = (newScale <= 0) ? 0.00001 : newScale, 
		mivHolW = this.$mivHol.width(),
		mivHolH = this.$mivHol.height(),
		defContentW = this.contentFullSize.w,
		defContentH = this.contentFullSize.h,
		newContentW = defContentW * safeScale,
		newContentH = defContentH * safeScale,
		horScale = mivHolW/defContentW, 
		verScale = mivHolH/defContentH,
		mivHolProp = mivHolW/mivHolH, //viewport proportion; p < 1 -  vertical; p > 1 - horizontal
		contentProp = newContentW/newContentH; //content proportion
			

		if(this.sett.fitToViewportShortSide) {
			if(newContentW < mivHolW || newContentH < mivHolH) {
				horScale = mivHolW / this.contentFullSize.w; 
				verScale = mivHolH / this.contentFullSize.h; 
				safeScale = Math.max(horScale, verScale);
				
				if (!this.sett.contentSizeOver100 && (defContentW <= mivHolW || defContentH <= mivHolH))
				{
					safeScale = 1;
				}
			}
		} else {
			if (newContentW < mivHolW && newContentH < mivHolH) {
				if (contentProp <= mivHolProp)
					safeScale = verScale;
				else
					safeScale = horScale;
			}
			
			if (!this.sett.contentSizeOver100 && defContentW <= mivHolW && defContentH <= mivHolH)
			{
				safeScale = 1;
			}
		}

		return safeScale;	
	}
	LocationChanger.prototype.getLimit = function (inScale) {
		var xMin = -(Math.round(this.contentFullSize.w * inScale) - this.$mivHol.width()),
		yMin = -(Math.round(this.contentFullSize.h * inScale) - this.$mivHol.height());
		return {'xMin' : xMin, 'xMax' : 0, 'yMin' : yMin, 'yMax' : 0};
	}
	LocationChanger.prototype.getSafeXY = function (x, y, inScale) {
		var limits = this.getLimit(inScale),
		mivHolW = this.$mivHol.width(),
		mivHolH = this.$mivHol.height(),
		mivHolCentX = mivHolW/2,
		mivHolCentY = mivHolH/2,
		defContentW = this.contentFullSize.w,
		defContentH = this.contentFullSize.h,
		newContentW = defContentW * inScale,
		newContentH = defContentH * inScale,
		safeX = x, safeY = y;
		
		
		/*X*/
		if (newContentW < mivHolW)
		{
			if (x < limits.xMin || x > limits.xMax)
				safeX = mivHolCentX - newContentW / 2;
		}
		else
		{
			if(x < limits.xMin) {
				safeX = limits.xMin;
			} else if(x > limits.xMax) {
				safeX = limits.xMax;
			}
		}
		
		/*Y*/
		if (newContentH < mivHolH)
		{
			if (y < limits.yMin || y > limits.yMax)
				safeY = mivHolCentY - newContentH / 2;
		}
		else
		{
			if(y < limits.yMin) {
				safeY = limits.yMin;
			} else if(y > limits.yMax) {
				safeY = limits.yMax;
			}
		}
		
		return {'x' : safeX, 'y' : safeY};
	}
	LocationChanger.prototype.animSizeAndPos = function (x, y, w, h, noAnim) {
		var safeXY, iterimScale,
		stepHandlerAnimPos =  function(_this) { 
			return function() { 
				_this.dispatchEventChange();
			} 
		}(this),
		completeHandlerAnimPos =  function(_this) { 
			return function() { 
				_this.dispatchEventChange();
			} 
		}(this),
		stepHandlerAnimSize =  function(_this) { 
			return function() {
				_this.dispatchEventChange();
			} 
		}(this),
		completeHandlerAnimSize =  function(_this) { 
			return function() {
				_this.isScaled = false;
				_this.dispatchEventChange();
			} 
		}(this);
		

		if(w != undefined) {
			iterimScale =  w / this.contentFullSize.w;
		} else {
			iterimScale =  this.$content.width() / this.contentFullSize.w;
		}
		
		if(x != undefined && y != undefined) {
			safeXY = this.getSafeXY(x, y, iterimScale);
			if(noAnim) {
				this.$contentHol.css({ left : safeXY.x, top : safeXY.y });
				completeHandlerAnimPos();
			} else {
				this.$contentHol.animate({ left : safeXY.x, top : safeXY.y }, 
										 { duration : this.sett.animTime, easing : 'easeOutCubic', 
										   step : stepHandlerAnimPos,
										   complete : completeHandlerAnimPos });
			}
		}
		if(w != undefined && h != undefined && (w != this.$content.width() || h != this.$content.height())) {
			this.isScaled = true;
			if(noAnim) {
				this.$content.css({ width : w, height : h });
				stepHandlerAnimSize();
				completeHandlerAnimSize();
			} else {
				this.$content.animate({ width : w, height : h }, 
									  { duration : this.sett.animTime, easing : 'easeOutCubic',
										step : stepHandlerAnimSize,
										complete : completeHandlerAnimSize }); 
			}
		}
	}
	LocationChanger.prototype.animStop = function (saveScale) {
		if(this.$contentHol && this.$content) {
			this.$contentHol.stop().clearQueue();
			this.$content.stop().clearQueue();
			
			if(saveScale) {
				this.sm.setScale(this.$content.width() / this.contentFullSize.w);
			}
			
			this.dispatchEventChange();
		}
	}
	LocationChanger.prototype.dispatchEventChange = function () {
		var a = this.getCurrentState(),
		e = $.Event("mivChange", a);

		this.allow = a;
		this.$mainHolder.trigger(e);
	}
	LocationChanger.prototype.getCurrentState = function () {
		var a = {};
		
		if(this.$content) {
		
			var contentHolPos = this.$contentHol.position(),
			limits = this.getLimit(this.sm.getScale()),
			contentW = this.$content.width(),
			contentH = this.$content.height(),
			mivCenter = {'x' : (this.$mivHol.width() / 2), 'y' : (this.$mivHol.height() / 2)},
			iterimScale =  contentW / this.contentFullSize.w;

			/*position*/
			a.allowDown = (Math.ceil(contentHolPos.top) < Math.ceil(limits.yMax));
			a.allowUp = (Math.ceil(contentHolPos.top) > Math.ceil(limits.yMin));
			a.allowRight = (Math.ceil(contentHolPos.left) < Math.ceil(limits.xMax));
			a.allowLeft = (Math.ceil(contentHolPos.left) > Math.ceil(limits.xMin));

			/*scale*/
			a.allowZoom = (contentW / this.contentFullSize.w < 1);
			if(this.sett.fitToViewportShortSide) {
				a.allowUnzoom = (contentW > this.$mivHol.width() && contentH > this.$mivHol.height());
			} else {
				a.allowUnzoom = (contentW > this.$mivHol.width() || contentH > this.$mivHol.height());
			} 

			/*prop width, height viewport-content*/
			a.wPropViewpContent = this.$mivHol.width() / contentW;
			a.hPropViewpContent = this.$mivHol.height() / contentH;

			/*content position in viewport center*/
			a.xPosInCenter = Math.round((-contentHolPos.left + mivCenter.x) / iterimScale);
			a.yPosInCenter = Math.round((-contentHolPos.top + mivCenter.y) / iterimScale);

			/*scale*/
			a.scale = iterimScale;

			/*is scaled*/
			a.isScaled = this.isScaled;
		
		}
		
		return a;
	}
	
	
	LocationChanger.prototype.allowCompare = function (_new, _old) {
		var res = true;
		
		$.each(_new, function(k){
			if(_new[k] != _old[k]) {
				res = false;
				return;
			}
		});
		
		return res;
	}
	
	/*scale manager*/
	var ScaleManager = function() {
		this.step = .1;
		this.curr = 1;
	};
	ScaleManager.prototype.getScale = function() {
		return this.curr;
	}
	ScaleManager.prototype.setScale = function(v) {
		this.curr = v;
	}
	ScaleManager.prototype.nextScale = function() {
		var scale = this.curr + this.step;
		if(scale > 1) {
			this.curr = 1;
		} else {
			this.curr = scale;
		}
		return this.getScale();
	}
	ScaleManager.prototype.prevScale = function() {
		var scale = this.curr - this.step;
		if(scale < this.step) {
			this.curr = 0;
		} else {
			this.curr = scale;
		}
		return this.getScale();
	}
	/**/
	
	/*content loaders*/
	var LoaderImgContent = function (url, $imgHolder, callback) {
		this.url = url;
		this.$imgHolder = $imgHolder;
		this.callback = callback;
	}
	LoaderImgContent.prototype.loadStart = function() {
		var $img = $('<img/>');

		$img.one('load', function (that){ 
			return function (e) {
				that.loadComplete(e);
			}
		}(this));

		this.$imgHolder.prepend($img);
		$img.attr('src', this.url); //load
	}
	LoaderImgContent.prototype.loadComplete = function(e) {
		if(this.callback) {
			this.callback($(e.currentTarget));
		}
	}
	LoaderImgContent.prototype.dispose = function() {
		this.callback = null;
	}
	/**/
	
	/*map*/
	var Map = function (sett, $mainHolder, $previewImg, isTouchDev) {
		this.contentLoader = null;
		this.isTouchDev = isTouchDev;
		this.sett = sett;
		this.$mainHolder = $mainHolder;
		this.$previewImg = $previewImg;
		this.$img = null;
		this.$mapHol = null;
		this.$mapWrappHol = null;
		this.$vr = null;
		this.lastMousePageCoor = {};
		this.contentLoadStartTimeout;
	}
	Map.prototype.ini = function ($mivHol) {
		this.$mapHol =  $('<div class="lhp_miv_map"/>');
		this.$mapWrappHol = $('<div class="lhp_miv_map_wrapp_hol"/>');
		this.$mapHol.append(this.$mapWrappHol);
		
		$mivHol.prepend(this.$mapHol);
		
		/*load content*/
		this.contentLoader = new LoaderImgContent(this.sett.mapThumb, this.$mapWrappHol, function(that) { 
			return function($content) {
				that.start($content);
			}
		}(this));
		
		var _this = this;
		this.contentLoadStartTimeout = setTimeout(function() {
			return function() {_this.contentLoader.loadStart();}
		}(), 10);
	}
	Map.prototype.start = function ($content) {
		var w = $content.width(),
		h = $content.height(),
		e;
		
		this.$img = $content;
		this.$img.css({'cursor' : 'pointer'});
		
		this.$mapHol.addClass('lhp_miv_map_pos_' + this.sett.mapPos)
		.css({'width' : w, 'height' : h});

		this.$mapWrappHol.addClass('lhp_miv_map_wrapp_hol_' + this.sett.mapPos)
		.css({'width' : w, 'height' : h});

		switch(this.sett.mapPos) {
			case 'T':
			case 'B':
				this.$mapHol.css('margin-left', -w/2)
				break;
			case 'L':
			case 'R':
				this.$mapHol.css('margin-top', -h/2)
				break;
		}

		this.$mapWrappHol.append(this.$img);

		this.$vr  =  $('<div class="lhp_miv_map_vr"/>')
		.css({'position' : 'absolute', 'z-index' : 2})
		.appendTo(this.$mapWrappHol);

		this.vrAddInteractions();
		this.$mainHolder.bind('mivChange.lhpMIV', {'_this' : this}, this.mivChangeHandler);
		
		e = this.$mainHolder.lhpMegaImgViewer('getCurrentState');
		e.data = {};
		e.data._this = this;
		this.mivChangeHandler(e);
	}
	Map.prototype.destroy = function () {
		clearTimeout(this.contentLoadStartTimeout);
		
		/*clear handler*/
		this.$vr.unbind('.lhpMIV');
		this.$mapHol.unbind('.lhpMIV');
		this.$img.unbind('.lhpMIV');
		this.contentLoader.dispose();
		this.contentLoader = null;

	}
	Map.prototype.vrAddInteractions = function () {
		this.$vr.bind('mouseenter.lhpMIV', {'_this' : this}, this.mouseenterHandler);

		if(this.isTouchDev) {
			this.$vr.bind('touchstart.lhpMIV', {'_this' : this}, this.mousedownHandler);
			this.$vr.bind('touchend.lhpMIV', {'_this' : this}, this.mouseupHandler);
			this.$img.bind('touchstart.lhpMIV', {'_this' : this}, this.mouseclickHandler);
		} else {
			this.$vr.bind('mousedown.lhpMIV', {'_this' : this}, this.mousedownHandler);
			this.$mapHol.bind('mouseup.lhpMIV', {'_this' : this}, this.mouseupHandler);
			this.$mapHol.bind('mouseleave.lhpMIV', {'_this' : this}, this.mouseupHandler);
			this.$img.bind('click.lhpMIV', {'_this' : this}, this.mouseclickHandler);
		}
	}
	//mouse handlers
	Map.prototype.mouseenterHandler = function (e) {
		e.data._this.$vr.css('cursor', 'url(//gallery/lhp_miv/cursorHand.png),default');
	}
	Map.prototype.mousedownHandler = function (e) {
		var _this = e.data._this;

		_this.$mainHolder.unbind('mivChange.lhpMIV', _this.mivChangeHandler);

		if(_this.isTouchDev) {
			_this.$mapHol.unbind('touchmove.lhpMIV', _this.mousemoveHandler).bind('touchmove.lhpMIV', {'_this' : _this}, _this.mousemoveHandler);
		} else {
			_this.$mapHol.unbind('mousemove.lhpMIV', _this.mousemoveHandler).bind('mousemove.lhpMIV', {'_this' : _this}, _this.mousemoveHandler);
		}

		_this.$vr.unbind('mouseenter.lhpMIV', _this.mouseenterHandler);
		_this.lastMousePageCoor = _this.mousePageCoor(e);
		_this.$vr.css('cursor', 'url(//gallery/lhp_miv/cursorDrag.png), move').addClass('lhp_miv_map_vr_over');
		e.preventDefault();
	}
	Map.prototype.mousemoveHandler = function (e) {
		var _this = e.data._this;

		if(_this.isTouchDev) {
			_this.$mapHol.unbind({'touchend.lhpMIV' : _this.stopDraggingHandler}).bind('touchend.lhpMIV' , {'_this' : _this}, _this.stopDraggingHandler);
		} else {
			_this.$mapHol.unbind({'mouseup.lhpMIV' : _this.stopDraggingHandler}).bind('mouseup.lhpMIV' , {'_this' : _this}, _this.stopDraggingHandler);
			_this.$mapHol.unbind({'mouseleave.lhpMIV' : _this.stopDraggingHandler}).bind('mouseleave.lhpMIV' , {'_this' : _this}, _this.stopDraggingHandler);
		}

		_this.dragging(e);
		e.preventDefault();
	}
	Map.prototype.mouseupHandler = function (e) {
		var _this = e.data._this;
		_this.$mapHol.unbind('touchmove.lhpMIV', _this.mousemoveHandler);
		_this.$mapHol.unbind('mousemove.lhpMIV', _this.mousemoveHandler);
		_this.$vr.unbind('mouseenter.lhpMIV', _this.mouseenterHandler).bind('mouseenter.lhpMIV', {'_this' : _this}, _this.mouseenterHandler);
		_this.$mainHolder.unbind('mivChange.lhpMIV', _this.mivChangeHandler).bind('mivChange.lhpMIV', {'_this' : _this}, _this.mivChangeHandler);
		_this.$vr.css('cursor', 'url(//gallery/lhp_miv/cursorHand.png),default').removeClass('lhp_miv_map_vr_over');
	}
	Map.prototype.mouseclickHandler = function (e) {
		var _this = e.data._this,
		mousePageCoor = _this.mousePageCoor(e),
		mapHolOffset = _this.$mapHol.offset(),
		x = (mousePageCoor.x - mapHolOffset.left) * _this.sett.mainImgWidth / _this.$mapWrappHol.width(),
		y = (mousePageCoor.y - mapHolOffset.top) * _this.sett.mainImgHeight / _this.$mapWrappHol.height();

		_this.$mainHolder.lhpMegaImgViewer('setPosition', x, y)
	}
	//changers
	Map.prototype.dragging = function (e) {
		var mousePageCoor = this.mousePageCoor(e),
		draggShftX = mousePageCoor.x - this.lastMousePageCoor.x,
		draggShftY = mousePageCoor.y - this.lastMousePageCoor.y,
		contentHolPos = this.$vr.position(),
		targetX = contentHolPos.left + draggShftX,
		targetY = contentHolPos.top + draggShftY,
		safeTarget = this.getSafeTarget(targetX, targetY, draggShftX, draggShftY);

		this.$vr.css({'left' : safeTarget.x, 'top' : safeTarget.y});              
		this.lastMousePageCoor = mousePageCoor;
		this.mainHolderSetPosition(safeTarget.x, safeTarget.y);
	}
	Map.prototype.stopDraggingHandler = function (e) {
		var _this = e.data._this;
		_this.$mapHol.unbind({'touchend.lhpMIV' : _this.stopDraggingHandler});
		_this.$mapHol.unbind({'mouseup.lhpMIV' : _this.stopDraggingHandler});
		_this.$mapHol.unbind({'mouseleave.lhpMIV' : _this.stopDraggingHandler});
	}
	Map.prototype.mousePageCoor = function (e) {
		var r = {x : e.pageX, y : e.pageY};
		e = e.originalEvent;
		if(this.isTouchDev && e) {
				r.x = e.changedTouches[0].pageX; 
				r.y = e.changedTouches[0].pageY;
		}
		return r;
	}
	Map.prototype.getSafeTarget = function (targetX, targetY, moveDirectX, moveDirectY) {
		var xMin = 0, yMin = 0,
		xMax = this.$mapWrappHol.width() - this.$vr.width(),
		yMax = this.$mapWrappHol.height() - this.$vr.height();

		/*Y*/
		if((moveDirectY < 0) && (targetY < yMin)) { //move up limit
			targetY = yMin;
		} else if((moveDirectY > 0) && (targetY > yMax)) { // move down limit
			targetY = yMax;
		}

		/*X*/
		if((moveDirectX < 0) && (targetX < xMin)) { //move left limit
			targetX = xMin;
		} else if((moveDirectX > 0) && (targetX > xMax)) { //move right limit 
			targetX = xMax;
		}

		return {x : targetX, y : targetY};
	}
	Map.prototype.mainHolderSetPosition = function (vrX, vrY) {
		var x = (vrX + this.$vr.width()/2) * this.sett.mainImgWidth / this.$mapWrappHol.width(),
		y = (vrY + this.$vr.height()/2) * this.sett.mainImgHeight / this.$mapWrappHol.height();

		this.$mainHolder.lhpMegaImgViewer('setPosition', x, y, null, true);
	}
	Map.prototype.mivChangeHandler = function (e) {
		var _this = e.data._this,
		mapW = _this.$mapWrappHol.width(),
		mapH = _this.$mapWrappHol.height(),
		vrW = Math.round(mapW * ((e.wPropViewpContent > 1) ? 1 : e.wPropViewpContent)),
		vrH = Math.round(mapH * ((e.hPropViewpContent > 1) ? 1 : e.hPropViewpContent)),
		vrX = Math.round((mapW / _this.sett.mainImgWidth) * e.xPosInCenter - (vrW / 2)),
		vrY = Math.round((mapH / _this.sett.mainImgHeight) * e.yPosInCenter - (vrH / 2));

		_this.$vr.css({'width' : vrW, 'height' : vrH, 'left' : vrX, 'top' : vrY});
	}
	/**/
	
	/*markers*/
	var Markers = function ($mainHolder, $contentHol, containerId, isTouchDev, popupShowAction, startScale) {
		this.$mainHolder = $mainHolder;
		this.$contentHol = $contentHol;
		this.containerId = containerId;
		this.mClass = 'lhp_miv_hotspot';
		this.mInnClass = 'lhp_miv_marker';
		this.pClass = 'lhp_miv_popup';
		this.isTouchDev = isTouchDev;
		this.markers = [];
		this.popups = [];
		this.currShowPopup = null;
		this.popupShowAction = popupShowAction;
		this.startScale = startScale;

	}
	Markers.prototype.ini = function () {
		var _this = this,
		e;

		$('#' + this.containerId).find('.' + this.mClass).each(function(){
			_this.addMarker($(this).clone(true, true));
		});

		this.$mainHolder.bind('mivChange.lhpMIV', {'_this' : this}, this.mivChangeHandler); 
		
		if(this.startScale == 1) {
			this.positionsMarkers(1);
		}
	}
	Markers.prototype.destroy = function () {
		var i;

		for(i in this.markers) {
			this.markers[i].destroy();
		}

		for(i in this.popups) {
			this.popups[i].destroy();
		}

		this.$mainHolder = null;
		this.$contentHol = null;
		this.markers = null;
		this.popups = null;
	}
	Markers.prototype.addMarker = function ($m) {
		var id = 0, 
		x = 0, 
		y = 0, 
		visibleScale = 0,
		url,
		marker,
		popup,
		p;

		if($m.attr('data-id')) {
			id = $m.attr('data-id');
		}

		if($m.attr('data-x')) {
			x = parseInt($m.attr('data-x'));
		}

		if($m.attr('data-y')) {
			y = parseInt($m.attr('data-y'));
		}

		if($m.attr('data-visible-scale')) {
			visibleScale = parseFloat($m.attr('data-visible-scale'));
		}

		if($m.attr('data-url')) {
			url = $m.attr('data-url');
		}

		p = $m.find('.'+this.pClass).remove()[0];

		/*marker*/
		this.$contentHol.append($m);
		marker = new Marker(this, id, x, y, visibleScale, url, $m);
		this.markers.push(marker);
		/**/

		/*popup window*/
		if(p) {
			this.$contentHol.append(p);
			popup = new Popup(id, $(p), marker);
			popup.ini();
			this.popups.push(popup);
			marker.popup = popup;
		}
		/**/

		marker.ini();
	}
	Markers.prototype.mivChangeHandler = function (e) {
		var _this = e.data._this;

		if(e.isScaled) {
			_this.positionsMarkers(e.scale);
			_this.positionsPopup();
		} else {
			_this.positionsPopup();
		}
	}
	Markers.prototype.positionsMarkers = function (inScale) {
		var i, marker;

		for(i in this.markers) {
			marker = this.markers[i];
			marker.positions(inScale);
			marker.visibility(inScale);
		}
	}
	Markers.prototype.positionsPopup = function () {
		if(this.currShowPopup) {
			this.currShowPopup.positions();
		}
	}
	Markers.prototype.getLimit = function () {
		var contentHolPos = this.$contentHol.position(),
		xMin = -contentHolPos.left,
		xMax = xMin + this.$mainHolder.width(),
		yMin = -contentHolPos.top,
		yMax = yMin + this.$mainHolder.height();

		return {'xMin' : xMin, 'xMax' : xMax, 'yMin' : yMin, 'yMax' : yMax};
	}
	Markers.prototype.showPopup = function (popup) {

		if(!this.currShowPopup) {
			this.currShowPopup = popup;
			this.currShowPopup.show();
			this.currShowPopup.positions();
			return;
		}

		if(this.currShowPopup && this.currShowPopup != popup) {
			this.hidePopup(this.currShowPopup);
			this.currShowPopup = popup;
			this.currShowPopup.show();
			this.currShowPopup.positions();
		}
	}
	Markers.prototype.hidePopup = function (popup) {

		if(this.currShowPopup && this.currShowPopup == popup) {
			this.currShowPopup.hide();
			this.currShowPopup = null;
		}
	}
	/**/

	/*marker*/
	var Marker = function (markers, id, x, y, visibleScale, url, $m) {
		this.markers = markers;
		this.id = id;
		this.x = x;
		this.y = y;
		this.visibleScale = visibleScale;
		this.url = url;
		this.$m = $m;
		this.visible = false;
		this.popup = null;
		this.popupClose = null;
	}
	Marker.prototype.ini = function () {
		this.style();
		this.positions(1);

		if(this.url) {
			this.addInteractivityUrl();
		}

		if(this.popup) {
			this.popupClose = this.popup.addClose();
			this.addPopupAction();
		} else {
			if(this.markers.popupShowAction == 'rollover')
				this.addPopupActionNull();
		}
	}
	Marker.prototype.destroy = function () {
		this.getInn().unbind('.lhpMIV');
		
		if(this.popup) {
			this.popupClose.unbind('.lhpMIV');
			this.popupClose = null;
			this.popup = null;
		}

		this.$m = null;
		this.markers = null;
	}
	Marker.prototype.getInn = function () {
		return this.$m.find('.'+this.markers.mInnClass);
	}
	Marker.prototype.getSize = function () {
		return {'w' : this.getInn().width(), 'h' : this.getInn().height()};
	}
	Marker.prototype.getEdges = function () {
		return this.findEdges();
	}
	Marker.prototype.findEdges = function () {
		var mInnOff = this.getInn().offset(),
		mainHolOff = this.markers.$mainHolder.offset(),
		contentHolPos = this.markers.$contentHol.position(),
		contentL = contentHolPos.left,
		contentT = contentHolPos.top,
		mSize = this.getSize(),
		l = mInnOff.left - contentL - mainHolOff.left,
		r = l + mSize.w,
		t = mInnOff.top - contentT - mainHolOff.top,
		b = t + mSize.h;

		return({'L' : l, 'R' : r, 'T' : t, 'B' : b});
	}
	Marker.prototype.getLimit = function () {
		return this.markers.getLimit();
	}
	Marker.prototype.style = function () {
		var css = {'position' : 'absolute',
					'z-index' : '2',
					'display' : 'none'};

		this.$m.css(css);
		this.$m.css('height', this.$m.height());
	}
	Marker.prototype.positions = function (inScale) {
		var x = Math.round(this.x * inScale),
		y = Math.round(this.y * inScale);

		this.$m.css({'left' : x, 'top' : y});
	}
	Marker.prototype.visibility = function (inScale) {
		if(inScale >= this.visibleScale) {
			if(!this.visible) this.$m.stop(true, true).fadeIn(300);
			this.visible = true;
		} else {
			if(this.visible) this.$m.fadeOut(300);
			this.visible = false;
			this.markers.hidePopup(this.popup);
		}
	}
	Marker.prototype.addInteractivityUrl = function () {
		this.getInn().css('cursor', 'pointer');
		this.getInn().bind( ((this.markers.isTouchDev) ? 'touchstart.lhpMIV' : 'mousedown.lhpMIV'), {'_this' : this}, this.clickHandlerUrl);
	}
	Marker.prototype.clickHandlerUrl = function (e) {
		var _this = e.data._this

		if(_this.url) {
			window.location = _this.url;
		}

		e.stopPropagation();
	}
	Marker.prototype.addPopupAction = function () {

		if(this.markers.popupShowAction == 'click') {
			this.getInn().bind( ((this.markers.isTouchDev) ? 'touchstart.lhpMIV' : 'mousedown.lhpMIV'), {'_this' : this}, this.showPopup);
			this.getInn().css('cursor', 'pointer');
		} else {
			this.getInn().bind( ((this.markers.isTouchDev) ? 'touchstart.lhpMIV' : 'mouseenter.lhpMIV'), {'_this' : this}, this.showPopup);
		}

		this.popupClose.bind( ((this.markers.isTouchDev) ? 'touchstart.lhpMIV' : 'mousedown.lhpMIV'), {'_this' : this}, this.hidePopup);

	}
	Marker.prototype.addPopupActionNull = function () {
		this.getInn().bind( ((this.markers.isTouchDev) ? 'touchstart.lhpMIV' : 'mouseenter.lhpMIV'), {'_this' : this}, this.showPopup);
	}
	Marker.prototype.showPopup = function (e) {
		var _this = e.data._this;

		_this.markers.showPopup(_this.popup);
		e.stopPropagation();
	}
	Marker.prototype.hidePopup = function (e) {
		var _this = e.data._this;

		_this.markers.hidePopup(_this.popup);
		e.stopPropagation();
	}
	/**/

	/*popup*/
	var Popup = function (id, $p, marker) {
		this.id = id;
		this.$p = $p;
		this.marker = marker;
		this.posHor = this.posHC;
		this.posVer = this.posVT;
		this.$closeHolder = null;
	}
	Popup.prototype.ini = function () {

		/*positioning type*/
		if(this.$p.hasClass('pos-TL')) {
			this.posHor = this.posHL;
			this.posVer = this.posVT;
		} else if(this.$p.hasClass('pos-T')) {
			this.posHor = this.posHC;
			this.posVer = this.posVT;
		} else if(this.$p.hasClass('pos-TR')) {
			this.posHor = this.posHR;
			this.posVer = this.posVT;
		} else if(this.$p.hasClass('pos-L')) {
			this.posHor = this.posHL;
			this.posVer = this.posVC;
		} else if(this.$p.hasClass('pos-R')) {
			this.posHor = this.posHR;
			this.posVer = this.posVC;
		} else if(this.$p.hasClass('pos-BL')) {
			this.posHor = this.posHL;
			this.posVer = this.posVB;
		} else if(this.$p.hasClass('pos-B')) {
			this.posHor = this.posHC;
			this.posVer = this.posVB;
		} else if(this.$p.hasClass('pos-BR')) {
			this.posHor = this.posHR;
			this.posVer = this.posVB;
		}
		/**/

		this.style();
		this.positions(1);
	}
	Popup.prototype.destroy = function () {
		this.$p = null;
		this.marker = null;
	}
	Popup.prototype.style = function () {
		var css = {'display' : 'none',
					'position' : 'absolute',
					'z-index' : '3'};

		this.$p.css(css);
		this.$p.css('height', this.$p.height());
	}
	Popup.prototype.addClose = function () {
		this.$closeHolder = $('<div class="lhp_miv_popup_close"></div>');

		this.$closeHolder.hover(
			function () { $(this).css('opacity', .7); }, 
			function () { $(this).css('opacity', 1); }
		);

		this.$p.append(this.$closeHolder);
		return this.$closeHolder;
	}
	Popup.prototype.getSize = function () {
		return {'w' : this.$p.width(), 'h' : this.$p.height()};
	}
	Popup.prototype.positions = function () {
		var mEdges = this.marker.getEdges(),
		x = this.posHor(mEdges), 
		y = this.posVer(mEdges),
		limit = this.marker.getLimit(),
		w = this.$p.width(),
		h = this.$p.height();

		/*X*/
		if(x < limit.xMin) {
			x = limit.xMin;
		} else if (x+w > limit.xMax) {
			x = limit.xMax - w;
		}

		/*Y*/
		if(y < limit.yMin) {
			y = limit.yMin;
		} else if (y+h > limit.yMax) {
			y = limit.yMax - h;
		}

		this.$p.css({'left' : x, 'top' : y});
	}
	Popup.prototype.posVT = function (mEdges) {
		return Math.round(mEdges.T) - this.$p.height();
	}
	Popup.prototype.posVC = function (mEdges) {
		return Math.round(mEdges.T + (mEdges.B - mEdges.T)/2) - this.$p.height()/2;
	}
	Popup.prototype.posVB = function (mEdges) {
		return Math.round(mEdges.B);
	}
	Popup.prototype.posHL = function (mEdges) {
		return Math.round(mEdges.L) - this.$p.width();
	}
	Popup.prototype.posHC = function (mEdges) {
		return Math.round(mEdges.L + (mEdges.R - mEdges.L)/2) - this.$p.width()/2;
	}
	Popup.prototype.posHR = function (mEdges) {
		return Math.round(mEdges.R);
	}
	Popup.prototype.show = function () {
		this.$p.fadeIn(300);
	}
	Popup.prototype.hide = function () {
		this.$p.stop().clearQueue().fadeOut(100);
	}
	/**/

})(jQuery);
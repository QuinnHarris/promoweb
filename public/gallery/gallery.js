$(document).ready(function(){
	var settings = {
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
		'intNavPos' : 'B',
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
		'mapThumb' : '',
		'mapPos' : 'BL',
		'popupShowAction' : 'click',
		'testMode' : false
	};
	
   	$('#myDiv').lhpMegaImgViewer(settings);
	
	$('#galleryThumbImg a').each(function(index){
		$(this).click(function(e) {
			e.preventDefault();
			settings.contentUrl = $(this).attr('href');
			settings.mapThumb = $(this).find('img').attr('src');
			$('#myDiv').lhpMegaImgViewer('destroy');
			$('#myDiv').lhpMegaImgViewer(settings);
		});
	});
	$('#galleryThumbImg a:first').trigger('click');

	$('#galleryThumbImg img').each(function(index){
		$(this).hover(function(){
			$(this).stop(true, true).animate({'opacity':.4});
		},
		function () {
			$(this).stop(true, true).animate({'opacity':1});
		});
	});
});

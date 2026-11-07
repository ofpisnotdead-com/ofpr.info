jQuery.noConflict();
// cookie function
jQuery.cookie = function (key, value, options) {
    // key and at least value given, set cookie...
    if (arguments.length > 1 && String(value) !== "[object Object]") {
        options = jQuery.extend({}, options);
        if (value === null || value === undefined) {
            options.expires = -1;
        }
        if (typeof options.expires === 'number') {
            var days = options.expires, t = options.expires = new Date();
            t.setDate(t.getDate() + days);
        }

        value = String(value);

        return (document.cookie = [
            encodeURIComponent(key), '=',
            options.raw ? value : encodeURIComponent(value),
            options.expires ? '; expires=' + options.expires.toUTCString() : '', // use expires attribute, max-age is not supported by IE
            options.path ? '; path=' + options.path : '',
            options.domain ? '; domain=' + options.domain : '',
            options.secure ? '; secure' : ''
        ].join(''));
    }
    // key and possibly options given, get cookie...
    options = value || {};
    var result, decode = options.raw ? function (s) { return s; } : decodeURIComponent;
    return (result = new RegExp('(?:^|; )' + encodeURIComponent(key) + '=([^;]*)').exec(document.cookie)) ? decode(result[1]) : null;
};
//
var page_loaded = false;
//
jQuery(document).ready(function() {
	// NSP suffix showcase
	jQuery('.showcase').each(function(i, wrapper) {
		wrapper = jQuery(wrapper);
		if(wrapper.find('.nspImageWrapper').length > 0 && wrapper.find('.nspHeader').length > 0) {
			wrapper.find('.nspArt').each(function(i, art) {
				jQuery(art).find('.nspImageWrapper').append(jQuery(art).find('.nspHeader'));
			});
		}
	});
	
	jQuery('.showcase-small').each(function(i, wrapper) {
		wrapper = jQuery(wrapper);
		if(wrapper.find('.nspImageWrapper').length > 0 && wrapper.find('.nspHeader').length > 0) {
			wrapper.find('.nspArt').each(function(i, art) {
				jQuery(art).find('.nspImageWrapper').append(jQuery(art).find('.nspHeader'));
			});
		}
	});
});
//
jQuery(window).load(function() {
	setTimeout(function() {
		if(jQuery('#gkTopBar').length > 0) {
			jQuery('#gkTopBar').addClass('active');
		}
	}, 500);
	//
	page_loaded = true;

	if(jQuery(document.body).attr('data-smoothscroll') == '1') {
		// smooth anchor scrolling
		jQuery('a[href*="#"]').on('click', function (e) {
	        e.preventDefault();
	        if(this.hash !== '') {
	            var target = jQuery(this.hash);

	            if(this.hash !== '' && this.href.replace(this.hash, '') == window.location.href.replace(window.location.hash, '')) {    
	                if(target.length && this.hash !== '#') {
	                    jQuery('html, body').stop().animate({
	                        'scrollTop': target.offset().top
	                    }, 1000, 'swing', function () {
	                        if(this.hash !== '#') {
	                            window.location.hash = target.selector;
	                        }
	                    });
	                } else if(this.hash !== '' && this.href.replace(this.hash, '') !== '') {
	                    window.location.href = this.href;
	                }
	            } else if(this.hash !== '' && this.href.replace(this.hash, '') !== '') {
	                window.location.href = this.href;
	            }
	        }
	    });
	}
	// style area
	if(jQuery('#gkStyleArea').length > 0){
		jQuery('#gkStyleArea').find('a').each(function(i, element){
			jQuery(element).click(function(e){
				e.preventDefault();
				e.stopPropagation();
				changeStyle(i+1);
			});
		});
	}
	// font-size switcher
	if(jQuery('#gkTools').length > 0 && jQuery('#gkMainbody').length > 0) {
		var current_fs = 100;
		
		jQuery('#gkMainbody').css('font-size', current_fs+"%");
		
		jQuery('#gkToolsInc').click(function(e){ 
			e.stopPropagation();
			e.preventDefault(); 
			if(current_fs < 150) {  
				jQuery('#gkMainbody').animate({ 'font-size': (current_fs + 10) + "%"}, 200); 
				current_fs += 10; 
			} 
		});
		jQuery('#gkToolsReset').click(function(e){ 
			e.stopPropagation();
			e.preventDefault(); 
			jQuery('#gkMainbody').animate({ 'font-size' : "100%"}, 200); 
			current_fs = 100; 
		});
		jQuery('#gkToolsDec').click(function(e){ 
			e.stopPropagation();
			e.preventDefault(); 
			if(current_fs > 70) { 
				jQuery('#gkMainbody').animate({ 'font-size': (current_fs - 10) + "%"}, 200); 
				current_fs -= 10; 
			} 
		});
	}
	// system message container auto hide
	if(jQuery('#system-message-container').length > 0){
		jQuery('#system-message-container').each(function(i, element){
			(function() {
				jQuery(element).fadeOut('slow');
			}).delay(3500);
		});
	} 
	// K2 font-size switcher fix
	if(jQuery('#fontIncrease').length > 0 && jQuery('.itemIntroText').length > 0) {
		jQuery('#fontIncrease').click(function() {
			jQuery('.itemIntroText').attr('class', 'itemIntroText largerFontSize');
		});
		
		jQuery('#fontDecrease').click( function() {
			jQuery('.itemIntroText').attr('class', 'itemIntroText smallerFontSize');
		});
	}
	// login popup
	if(jQuery('#gkPopupLogin').length > 0 && jQuery('#gkLogin').length > 0) {
		var popup_overlay = jQuery('#gkPopupOverlay');
		popup_overlay.css({'display': 'none', 'opacity' : 0});
		popup_overlay.fadeOut();
		
		jQuery('#gkPopupLogin').css({'display': 'block', 'opacity': 0, 'height' : 0});
		var opened_popup = null;
		var popup_login = null;
		var popup_login_h = null;
		
		if(jQuery('#gkPopupLogin')) {

			popup_login = jQuery('#gkPopupLogin');
			popup_login.css('display', 'block');
			popup_login_h = popup_login.find('.gkPopupWrap').outerHeight();
			 
			jQuery('#gkLogin').click( function(e) {
				e.preventDefault();
				e.stopPropagation();
				popup_overlay.css({'opacity' : 0.45});
				popup_overlay.fadeIn('medium');
				
				setTimeout(function() {
					popup_login.animate({'opacity':1, 'height': popup_login_h},200, 'swing');
					opened_popup = 'login';
					popup_login.addClass('gk3Danim');
				}, 450);

				(function() {
					if(jQuery('#modlgn-username').length > 0) {
						jQuery('#modlgn-username').focus();
					}
				}).delay(600);
			});
		}
		
		popup_overlay.click( function() {
			if(opened_popup == 'login')	{
				popup_overlay.fadeOut('medium');
				popup_login.removeClass('gk3Danim');
				setTimeout(function() {
					popup_login.animate({
						'opacity' : 0
					},350, 'swing');
				}, 100);
				
			}
		});
	}

	var resize_boundary = parseInt(jQuery('body').data('tabletWidth'), 10);
	var mobile_resize_boundary = parseInt(jQuery('body').data('mobileWidth'), 10);
	var col_m = jQuery('#gkContentWrap');
	var col_s = jQuery('#gkSidebar');
	var col_i = jQuery('#gkInset');

	if(col_i.length > 0) {
		var columnResize = function() {
			col_m.css('min-height', '0');
			if(col_s) col_s.css('min-height', '0');
			col_i.css('min-height', '0');
			
			var col_m_h = col_m.height();
			var col_s_h = (col_s) ? col_s.height() : 0;
			var col_i_h = col_i.height();
			var max = col_m_h;

			if(jQuery(window).width > resize_boundary) {
				if(max < col_s_h) max = col_s_h;
				if(max < col_i_h) max = col_i_h;
				col_m.css('min-height', max + "px");
				if(col_s) col_s.css('min-height', max + "px");
				col_i.css('min-height', (max + 35) + "px");
			} else if(jQuery(window).width <= resize_boundary && jQuery(window).width() > mobile_resize_boundary) {
				col_m_h = col_m.height();
				col_i_h = col_i.height();
				max = col_m_h;
				if(max < col_i_h) max = col_i_h;
				if(col_s) col_s.css('min-height', "0");
				col_m.css('min-height', max + "px");
				col_i.css('min-height', max + "px");
			}
		};
		
		columnResize();
		
		setTimeout(function() { columnResize(); }, 1000);
		setTimeout(function() { columnResize(); }, 2500);
		setTimeout(function() { columnResize(); }, 5000);
		setTimeout(function() { columnResize(); }, 10000);
	
		jQuery(window).resize(function() {
			columnResize();
		});
	}
});
// Function to change styles
function changeStyle(style){
	var file1 = $GK_TMPL_URL+'/css/style'+style+'.css';
	var file2 = $GK_TMPL_URL+'/css/typography/typography.style'+style+'.css';
	jQuery('head').append('<link rel="stylesheet" href="'+file1+'" type="text/css" />');
	jQuery('head').append('<link rel="stylesheet" href="'+file2+'" type="text/css" />');
	jQuery.cookie('gk_game_j30_style', style, { expires: 365, path: '/' });
}
function installButton(toolbarId, id) {
	var toolbar = document.getElementById(toolbarId);
	var before = null;
	toolbar.insertItem(id, before);
	toolbar.setAttribute("currentset", toolbar.currentSet);
	document.persist(toolbar.id, "currentset");
}

var webc = {
	init: function() {
		if (gBrowser) {
			gBrowser.tabContainer.addEventListener("TabClose", webc.tabRemoved, false);
		}
		// COMMENT BELOW OUT only if showprintbutton is explicity set
		// installButton("nav-bar", "print-button");
	},
	tabRemoved: function(event) {

		// Get number of tabs
		var num = gBrowser.browsers.length;

		// If there are two tabs, the second tab has no title and the closed tab
		// does have a title (ie is not the same tab) then close the browser
		if ((num == 2) && (!gBrowser.getBrowserAtIndex(1).contentTitle) && event.target.linkedBrowser.contentTitle) {
			goQuitApplication();
		}
		if ((num == 2) && (!gBrowser.getBrowserAtIndex(0).contentTitle)) {
			goQuitApplication();
		}
	}

};

window.addEventListener("load", function load(event) {
	window.removeEventListener("load", load, false); //remove listener, no longer needed
	webc.init();
},
false);

function BrowserLoadURL(aTriggeringEvent, aPostData) { // override browser.js
	var url = gURLBar.value;
	if (url.match(/^file:/) || url.match(/^\//) || url.match(/^resource:/) || url.match(/^about:/)) {
		alert("Access to this protocol has been disabled!");
		return;
	}

	if (aTriggeringEvent instanceof MouseEvent) {
		if (aTriggeringEvent.button == 2) {
			return; // Do nothing for right clicks
		}

		// We have a mouse event (from the go button), so use the standard UI link behaviors
		openUILink(url, aTriggeringEvent, false, false, true, aPostData);
		return;
	}

	if (aTriggeringEvent && aTriggeringEvent.altKey) {
		handleURLBarRevert();
		content.focus();
		gBrowser.loadOneTab(url, null, null, aPostData, false, true
		/* allow third party fixup */
		);
		aTriggeringEvent.preventDefault();
		aTriggeringEvent.stopPropagation();
	}
	else {
		loadURI(url, null, aPostData, true
		/* allow third party fixup */
		);
	}

	focusElement(content);
}

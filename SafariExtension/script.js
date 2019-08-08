// Inject the iframe into the top frame
if (window.top === window) {
	safari.self.addEventListener("message", handleMessage);
	
	function handleMessage(event) {
		if (event.name == 'translate') {
			console.log("Injecting iframe");
			injectIframe();
		}
		else if (event.name == 'loadedData') {
			console.log("Got loaded data");
			console.log(event.message.title);
		}
	}
	
	function injectIframe() {
		var iframe = document.getElementById("zotero-iframe");
		if (iframe) {
			iframe.contentWindow.postMessage(['progressWindow.reopen', null], '*');
			return;
		};
		
		iframe = document.createElement("iframe");
		iframe.id = "zotero-iframe"
		iframe.style.display = "none";
		iframe.style.borderStyle = "none";
		iframe.setAttribute("frameborder", "0");
		iframe.src = 'https://zotero-temp.s3.amazonaws.com/bookmarklet/safari-test/iframe.html';
		document.body.appendChild(iframe);
	}
	
	document.addEventListener("DOMContentLoaded", function (event) {
		window.addEventListener('message', function (event) {
			if (event.origin == 'https://zotero-temp.s3.amazonaws.com' && event.data == 'Hello') {
				safari.extension.dispatchMessage("loadData");
			}
		});
	});
}

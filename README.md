# Zotero Safari App Extension Connector

## Building for Development

1. Clone this repository
1. Clone https://github.com/zotero/zotero-connectors next to it
1. Make sure the `zotero-connectors` repo directory is named `zotero-connectors` and
	placed in the same folder as this repository
1. Build the `zotero-connectors` repository
1. Open the project in XCode, select the topmost item in the Project navigator (ExtensionApp),
	and under each Target make sure you have a valid Team selectend under Signing and Capabilities
1. Build and run the project

Note: anytime the code in `zotero-connectors` is changed the project needs to be cleaned
(Cmd-Shift-K) before building, otherwise Safari complains about the signature being invalid.

## Developing/Structure

For the main readme on Zotero Connector architecture see https://github.com/zotero/zotero-connectors

This Connector is built using the [Safari App Extension](https://developer.apple.com/documentation/safariservices/safari_app_extensions)
framework. To allow for code reusability across Zotero Connectors the extension closely follows
the architecture existing in the Chrome and Firefox connectors.
Scripts related to translation (and Google Docs integration when appropriate) are injected into
each page via by specifying them in Info.plist under the `SFSafariContentScript` key.
The injected scripts communicate to the background page via message passing.

### Background page

The background page in the App Extension consists of 2 parts:

1. The "as intended by Apple" Swift class `SafariExtensionHandler`, which handles messages
	from the injected scripts, button and context menu interactions, file system access,
	cross-origin HTTP requests, and passes on messages to the JS background page.
1. The JS background page ported from the previous Safari extension, which contains most of the
	extension handling logic, such as orchestrating prefs and i18n strings,
	managing translators, issuing button icon and label, and context menu updates. It is
	created via the JavaScriptCore framework in the entry-point static class `GlobalPage`.

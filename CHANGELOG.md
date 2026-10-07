## 0.2.0

* `NusaChatPage.initialMessage`: prefills the composer; the visitor edits and sends it.
* Long-press a message to copy its text (or a media caption). Custom bubbles get it as `NusaChatMessageData.onLongPress`.
* Snackbar styling in `NusaChatTheme` (`snackBarColor`, `snackBarTextStyle`, `snackBarBehavior`, `snackBarRadius`, `snackBarDuration`, `snackBarMargin`), used by every notice in the chat, camera and photo editor. `showNusaChatSnackBar` shows one from custom UI.

**Breaking / visible changes**

* Snackbars no longer follow the host app's `SnackBarTheme`; they use the new `NusaChatTheme` snackbar fields
  (dark, floating, rounded by default).
* `NusaChatTheme`'s constructor has new required snackbar parameters. Themes made from
  `NusaChatTheme.fallback().copyWith(...)` are unaffected.

## 0.1.0

* Text chat over NusaContact Socket Bridge (session, history, WebSocket with Origin, HTTP fallback, reconnect + resync).
* Photos (gallery and in-app camera) with crop, rotate and drawing (pencil, text, arrow); documents, location and voice notes.
* Emoji panel with categories, search and recently used emoji.
* Day dividers, floating date while scrolling, full-screen photo viewer with pinch and double-tap zoom.
* Theme, strings and builders to restyle or replace every part of the screen.

## 0.5.1

* Web support. The chat, history, photos (gallery and in-app camera), photo crop and drawing, documents, voice
  notes and location work in the browser. Picked and edited files are kept as blob URLs and uploaded from memory.
* On the web the browser sends the page's own `Origin` on the REST calls and the WebSocket upgrade, so
  `NusaChatConfig.origin` is not sent there. The host page's origin must be in the website's `allowed_origins`,
  and the bridge must allow it for CORS.
* Voice notes on the web are Opus in WebM (`audio/webm`; Chrome, Firefox) or AAC in MP4 (`audio/mp4`; Safari).
* The in-app camera no longer closes when the camera has no zoom, torch or focus point (most webcams).

## 0.5.0

* `NusaChatClient.getConversations()`: a page of the visitor's conversations, including closed ones
  (`ChatConversationPage`, `ChatConversation`).
* `NusaChatClient.getVisitorMessages()`: the visitor's messages across all conversations, newest first.
  `ChatMessage.conversationId` tells which conversation each belongs to.
* `NusaChatClient.getConversationMessages()`: the messages of one conversation, open or closed.
* Reply buttons: agent `interactive` messages show their buttons under the bubble (`NusaChatMessageButtons`). A tap
  sends a `button_reply` and shows its title as the visitor's message; the buttons then stay disabled. Needs a
  bridge with `interactive` support (migration `0008_interactive_message_type`).
* `ChatMessageType.interactive`, `ChatButton`, `ChatMessage.buttons`, `ChatMessage.buttonReply`. Custom rows get
  `NusaChatMessageData.onButtonTap`.

**Breaking / visible changes**

* `NusaChatTheme`'s constructor has new required parameters (`messageButtonColor`, `messageButtonTextStyle`,
  `messageButtonDisabledOpacity`). Themes made from `NusaChatTheme.fallback().copyWith(...)` are unaffected.
* `ChatMessageType` has a new value, so an exhaustive `switch` on it in a host app must handle `interactive`.

## 0.4.0

* `NusaChatPage.initialMessages`: what the chat opens with, as `NusaChatInitialMessage`s — a text, images
  (local files), or both; each image is its own bubble and the text is the first image's caption.
* `NusaChatPage.autoSendInitialMessages`: sends them in order once the chat has loaded. Without it the texts
  prefill the composer and the images open in the pre-send preview.
* `NusaChatPage.initialMessage` is deprecated; use `initialMessages: [NusaChatInitialMessage(text: ...)]`.

## 0.3.0

* `NusaChatConfig.fcmToken`: sent as `fcm_token` with every session start. The bridge does not store it yet —
  push needs the backend to read this field.
* `NusaChatClient(config).getActiveSession()`: the visitor's open conversation (`ChatSession`) for the host
  app's own views, without opening the chat screen. Uses `POST .../sessions`, so a new conversation is opened
  when none is.

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

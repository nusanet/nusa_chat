## 0.6.0

* Videos: "Video" in the attachment menu picks one video from the system photo picker (no permission needed). It is
  trimmed to at most 1 minute 30 seconds on `NusaChatVideoTrimPage`, compressed on the device (H.264, up to 720p and
  30 fps, so the longest clip stays under 15 MB), then captioned and sent. On Android a whole video that already is
  H.264/AAC MP4, up to 720p and under the limit, is sent as it is, and the plugin's own encoder uses a constant bitrate,
  because Android raises a low variable bitrate to a quality floor. A video refused for its size, here or by the bridge,
  shows `NusaChatStrings.videoTooLarge`, which suggests a shorter video. Bubbles show `NusaChatVideoContent`; a tap
  opens `NusaChatVideoViewerPage`. Turn it off with `NusaChatAttachmentOptions(video: false)`. Needs a bridge that
  accepts `video/mp4` uploads and `video` messages.
* `ChatMessageType.video`, `ChatMedia.thumbnailPath`, `ChatAttachment.thumbnailPath`, `NusaChatTrimRange`,
  `NusaChatVideoSpec`, `NusaChatVideoInfo`, `NusaChatMediaError.compressionFailed`.
* `MediaTooLargeFailure` for an upload the bridge refuses for its size.
* The attachment menu's "Galeri" is now "Foto", since it only picks photos. `NusaChatStrings.attachGallery` keeps its
  name.

**Breaking / visible changes**

* `ChatMessageType` has a new value, so an exhaustive `switch` on it in a host app must handle `video`.
* `NusaChatAttachmentKind` and `NusaChatMediaError` have new values (`video`, `compressionFailed`).
* `NusaChatTheme`'s constructor has a new required parameter, `videoIconColor`.
* `NusaChatMediaService` has new methods (`pickVideo`, `videoInfo`, `videoThumbnails`, `compressVideo`,
  `cancelVideoCompression`, `discardVideo`, `downloadVideo`) that a custom implementation must add.
* Android apps need `minSdk` 24. nusa_chat now has native Android code (`NusaChatPlugin`) that uses Media3 1.9.2.

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

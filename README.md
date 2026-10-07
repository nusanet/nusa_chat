# nusa_chat

In-app customer chat ("NusaChat") for Flutter apps on **Android and iOS**, connected to a NusaContact Socket
Bridge over REST and WebSocket.

## Features

- Real-time text chat with history, optimistic sending, retry, HTTP fallback and automatic reconnect.
- Photos from the gallery or an in-app camera, with crop (free, 1:1, 4:5, 16:9, rotate) and drawing
  (pencil, text, arrow) before sending.
- Documents (PDF, Word, Excel), current location and voice notes.
- Emoji panel with categories, search (Indonesian and English) and recently used emoji.
- Long-press a message to copy its text.
- Day dividers and a floating date while scrolling; full-screen photo viewer with pinch and double-tap zoom.
- Restyle with `NusaChatTheme` / `NusaChatStrings`, or replace parts with builders.

## Usage

```dart
NusaChat.open(
  context,
  page: NusaChatPage(
    config: const NusaChatConfig(
      baseUrl: 'https://chat-nusa.example.com',
      websiteId: 'mynusa',
      origin: 'https://nusaselecta.app', // must be in the website's allowed_origins
      visitorId: '6281234567890',         // optional: your customer id / normalised phone
      displayName: 'Budi Santoso',        // optional: contact name for the agent
    ),
    onReportTap: () {},                   // shows the top-right report button
  ),
);
```

Without `visitorId` the server generates one and the plugin remembers it on the device, so the same visitor
resumes the same conversation.

### Opening with a message

```dart
NusaChatPage(
  config: config,
  initialMessage: 'Saya mau tanya soal pesanan #INV-123', // prefilled in the composer, not sent
)
```

### Platform setup

Each attachment needs its permission in the host app; turn off what you don't use with
`attachments: NusaChatAttachmentOptions(...)` (or `NusaChatAttachmentOptions.none()` for text only).

**Android** (`AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>                 <!-- camera -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>           <!-- voice notes -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/> <!-- location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

Photos use the system photo picker, so no storage permission is needed.

**iOS** (`Info.plist`): `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
`NSLocationWhenInUseUsageDescription`, and `NSPhotoLibraryUsageDescription` (iOS 13 only).

### Server requirement

`origin` must be registered in `allowed_origins` of the `websites` row for `websiteId` — otherwise the
session call returns `403` and the socket is closed with `1008`. No other backend change is needed.

## Customization

| What | How |
|---|---|
| Colours / text styles | `theme: NusaChatTheme.fallback().copyWith(myBubbleColor: …, sendButtonGradient: …)` |
| Texts | `strings: NusaChatStrings(title: 'Bantuan', agentName: 'CS Nusanet', hintText: …)` |
| App bar actions | `actions: [NusaChatIconButton(icon: Icon(Icons.call), onTap: …)]` |
| Back button | `leading:` (replace) or `onBack:` (behaviour) |
| Whole app bar | `appBarBuilder: (context, data) => AppBar(...)` — `data` has title, connection, onBack |
| Message row | `messageBuilder: (context, data, defaultWidget) => …` |
| Bubble only | `bubbleBuilder: (context, data) => …` (wire `data.onLongPress` to keep copy) |
| Agent avatar | `agentAvatarBuilder: (context) => NusaChatAvatar(child: Image.asset(...))` |
| Composer | `inputBarBuilder: (context, composer) => …` (`controller`, `focusNode`, `send`, `canSend`) |
| Send button | `sendButtonBuilder: (context, onSend) => …` (`onSend` is null when empty) |
| Loading / error / empty / connection banner | `loadingBuilder`, `errorBuilder`, `emptyBuilder`, `connectionBuilder` |
| Snackbar look | `theme: NusaChatTheme.fallback().copyWith(snackBarColor: …, snackBarTextStyle: …, snackBarBehavior: …, snackBarRadius: …, snackBarDuration: …, snackBarMargin: …)` |
| Notices (e.g. rate limited, "Pesan disalin") | `onNotice: (context, message) => …` replaces the snackbar entirely |

Every default widget (`NusaChatAppBar`, `NusaChatBubble`, `NusaChatMessageRow`, `NusaChatAvatar`,
`NusaChatInputBar`, `NusaChatSendButton`, `NusaChatIconButton`) is exported, so custom builders can reuse them.
They read colours from `NusaChatThemeScope.of(context)`.

## Behaviour

- Bootstrap `POST /v1/widget/{website_id}/sessions` → history `GET …/messages` → WebSocket `/v1/ws` with an explicit
  `Origin` header.
- Sent messages appear immediately (clock icon) and turn to a double check once the server saves them (`ack`). Acks carry no client
  id, so they are matched to pending messages in send order.
- `rate_limited` / errors mark the message failed — tap to resend.
- When the socket is down, text goes over the HTTP fallback.
- Disconnects reconnect with backoff (1s → 30s) and resync history with `?since=`. Close code `1008`
  (conversation closed after 24h idle) bootstraps a new conversation once.
- The socket is closed while the app is in the background and reopened on resume.

## Architecture

Clean architecture:

```
lib/src/
  config/            NusaChatConfig
  core/              error (Failure), use_cases (UseCase/StreamUseCase), theme, util/styles (colours, spacing, type)
  features/data/     data_sources (remote Dio, socket, local prefs), models (json_serializable), repositories
  features/domain/   entities, repositories (contract), use_cases
  features/presentation/  bloc/chat, pages/nusa_chat_page.dart, widgets
  injection_container.dart   own GetIt instance (never GetIt.instance)
```

## Development

```sh
flutter pub get
dart run build_runner build
flutter analyze && flutter test
```

### Example app + mock bridge

```sh
cd example
dart run tool/mock_bridge.dart                      # fake bridge on :4000, seeded with a sample conversation
flutter run                                         # emulator/simulator → 10.0.2.2 / 127.0.0.1
flutter run --dart-define=NUSA_CHAT_BASE_URL=http://<mac-lan-ip>:4000   # real device
curl -X POST localhost:4000/agent/<visitor_id> -d '{"text":"Halo dari agent"}'   # push an agent reply
```

Against a real bridge: `--dart-define=NUSA_CHAT_BASE_URL=… --dart-define=NUSA_CHAT_WEBSITE_ID=… --dart-define=NUSA_CHAT_ORIGIN=…`.

## License

MIT — see [LICENSE](LICENSE). Bundled fonts, icons and emoji data keep their own licenses; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

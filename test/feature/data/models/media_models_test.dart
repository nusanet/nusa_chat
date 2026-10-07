import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart' show NusaChatGoogleMap;
import 'package:nusa_chat/src/features/data/models/media/upload_media_response.dart';
import 'package:nusa_chat/src/features/data/models/message/message_response.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/socket/socket_event_model.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';

void main() {
  String resolve(String id) => 'https://chat.example.com/v1/widget/w/media/$id';

  group('SendMessageBody', () {
    test('pastikan pesan media sesuai protokol WS', () {
      expect(const SendMessageBody.media(messageType: 'image', mediaId: 'abc', caption: 'Lampu').toJson(), {
        'type': 'message',
        'message_type': 'image',
        'media_id': 'abc',
        'caption': 'Lampu',
      });
    });

    test('pastikan caption kosong tidak dikirim', () {
      expect(const SendMessageBody.media(messageType: 'audio', mediaId: 'abc').toJson(), {
        'type': 'message',
        'message_type': 'audio',
        'media_id': 'abc',
      });
    });

    test('pastikan lokasi sesuai protokol WS', () {
      expect(const SendMessageBody.location(latitude: -6.2, longitude: 106.8).toJson(), {
        'type': 'location',
        'latitude': -6.2,
        'longitude': 106.8,
      });
    });
  });

  group('UploadMediaResponse', () {
    test('pastikan media_id dan message_type terbaca', () {
      final response = UploadMediaResponse.fromJson({'media_id': 'abc', 'message_type': 'document'});
      expect(response.toEntity(), const UploadedMedia(mediaId: 'abc', messageType: 'document'));
    });

    test('pastikan FormatException kalau media_id kosong', () {
      expect(
        () => UploadMediaResponse.fromJson({'media_id': null, 'message_type': 'image'}).toEntity(),
        throwsFormatException,
      );
    });
  });

  group('MessageResponse media', () {
    test('pastikan dokumen inbound: caption, filename, dan media_id jadi URL', () {
      final message = const MessageResponse(
        messageId: 'm-1',
        direction: 'inbound',
        type: 'document',
        body: '{"caption":"Bukti bayar","filename":"Bukti_Pembayaran.pdf"}',
        mediaUrl: 'abc123',
      ).toEntity(resolveMediaUrl: resolve);

      expect(message.isMine, isTrue);
      expect(message.text, 'Bukti bayar');
      expect(message.media?.fileName, 'Bukti_Pembayaran.pdf');
      expect(message.media?.mediaId, 'abc123');
      expect(message.media?.url, resolve('abc123'));
      expect(message.media?.extension, 'pdf');
    });

    test('pastikan link langsung dari agent dipakai apa adanya', () {
      final message = const MessageResponse(
        messageId: 'm-2',
        direction: 'outbound',
        type: 'image',
        body: 'Ini fotonya',
        mediaUrl: 'https://cdn.example.com/a.jpg',
      ).toEntity(resolveMediaUrl: resolve);

      expect(message.text, 'Ini fotonya');
      expect(message.media, const ChatMedia(url: 'https://cdn.example.com/a.jpg'));
    });

    test('pastikan lokasi terbaca dari body JSON', () {
      final message = const MessageResponse(
        messageId: 'm-3',
        direction: 'inbound',
        type: 'location',
        body: '{"latitude":-6.2,"longitude":106.8}',
      ).toEntity();

      expect(message.location, const ChatLocation(latitude: -6.2, longitude: 106.8));
      expect(message.text, isEmpty);
    });

    test('pastikan body dokumen yang bukan JSON tetap jadi caption', () {
      final message = const MessageResponse(
        messageId: 'm-4',
        direction: 'outbound',
        type: 'document',
        body: 'lama',
        mediaUrl: 'https://cdn.example.com/a.pdf',
      ).toEntity();

      expect(message.text, 'lama');
      expect(message.media?.fileName, isNull);
    });
  });

  test('pastikan dokumen dari agent lewat WS membawa filename dan link', () {
    final event = SocketEventModel.fromJson({
      'type': 'message',
      'from': 'agent',
      'message_type': 'document',
      'media_url': 'https://cdn.example.com/invoice.pdf',
      'caption': 'Tagihan',
      'filename': 'invoice.pdf',
      'message_id': 'm-5',
    }).toEntity();

    final message = (event as ChatSocketIncomingMessage).message;
    expect(message.text, 'Tagihan');
    expect(message.media, const ChatMedia(url: 'https://cdn.example.com/invoice.pdf', fileName: 'invoice.pdf'));
  });

  test('pastikan ChatLocation membuka Google Maps', () {
    expect(
      const ChatLocation(latitude: -6.2, longitude: 106.8).mapsUri.toString(),
      'https://www.google.com/maps/search/?api=1&query=-6.2,106.8',
    );
  });

  test('pastikan URL Google Static Maps berisi pusat, marker, ukuran (maks 640) dan key', () {
    final uri = const NusaChatGoogleMap(
      apiKey: 'KEY',
    ).staticMapUri(const ChatLocation(latitude: -6.2, longitude: 106.8), width: 800, height: 120);

    expect(uri.host, 'maps.googleapis.com');
    expect(uri.path, '/maps/api/staticmap');
    expect(uri.queryParameters, {
      'center': '-6.2,106.8',
      'zoom': '16',
      'size': '640x120',
      'scale': '2',
      'maptype': 'roadmap',
      'language': 'id',
      'markers': 'color:red|-6.2,106.8',
      'key': 'KEY',
    });
  });
}

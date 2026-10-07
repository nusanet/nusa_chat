// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_media_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadMediaResponse _$UploadMediaResponseFromJson(Map<String, dynamic> json) =>
    UploadMediaResponse(mediaId: json['media_id'] as String?, messageType: json['message_type'] as String?);

Map<String, dynamic> _$UploadMediaResponseToJson(UploadMediaResponse instance) => <String, dynamic>{
  'media_id': instance.mediaId,
  'message_type': instance.messageType,
};

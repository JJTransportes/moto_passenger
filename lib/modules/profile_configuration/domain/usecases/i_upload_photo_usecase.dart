import 'dart:io';
import 'package:result_dart/result_dart.dart';

abstract class IUploadPhotoUsecase {
  AsyncResult<String> call(String userId, File imageFile);
}

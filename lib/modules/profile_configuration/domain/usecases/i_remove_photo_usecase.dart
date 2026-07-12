import 'package:result_dart/result_dart.dart';

abstract class IRemovePhotoUsecase {
  AsyncResult<bool> call(String userId);
}

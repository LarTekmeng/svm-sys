import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AvatarCacheManager extends CacheManager{

  static const key = 'avatarCache';
  AvatarCacheManager._()
  : super(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 50,
    ),
  );
  static final instance = AvatarCacheManager._();
}
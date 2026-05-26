import 'package:flutter/widgets.dart';

import '../data/sync_service.dart';

/// Optional [SyncService] without Provider (avoids Listenable + nullable issues).
class SyncScope extends InheritedWidget {
  const SyncScope({
    required this.sync,
    required super.child,
    super.key,
  });

  final SyncService? sync;

  static SyncService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SyncScope>()?.sync;
  }

  @override
  bool updateShouldNotify(SyncScope oldWidget) => sync != oldWidget.sync;
}

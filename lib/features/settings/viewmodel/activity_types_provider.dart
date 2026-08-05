import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/settings/model/activity_type.dart';
import 'package:sou9ix/features/settings/service/activity_types_repository.dart';

class ActivityTypesNotifier extends StateNotifier<List<ActivityType>> {
  ActivityTypesNotifier({ActivityTypesRepository? repository})
    : _repo = repository ?? ActivityTypesRepository(),
      super([]) {
    _subscription = _repo.watchAll().listen((types) => state = types);
  }

  final ActivityTypesRepository _repo;
  late final StreamSubscription<List<ActivityType>> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  /// Adds a custom activity type created on the fly from the admin
  /// onboarding wizard — a no-op if one with the same id already exists.
  void add(ActivityType type) {
    if (state.any((t) => t.id == type.id)) return;
    _repo.add(type);
  }
}

final activityTypesProvider =
    StateNotifierProvider<ActivityTypesNotifier, List<ActivityType>>(
      (ref) => ActivityTypesNotifier(),
    );

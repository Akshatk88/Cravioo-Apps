import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/dining/data/dining_repository.dart';
import 'package:food_user_application/features/dining/domain/dining_slot_model.dart';

const List<String> kWeekDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

List<DiningDaySlotsModel> buildDefaultDays() {
  return List.generate(
    7,
    (index) => DiningDaySlotsModel(
      dayOfWeek: index,
      day: kWeekDayNames[index],
      isOpen: false,
      slots: const [],
    ),
  );
}

class DiningSlotsState {
  final List<DiningDaySlotsModel> days;
  final List<DiningBlockedDateModel> blockedDates;
  final bool isSaving;
  final String? error;

  const DiningSlotsState({
    this.days = const [],
    this.blockedDates = const [],
    this.isSaving = false,
    this.error,
  });

  DiningSlotsState copyWith({
    List<DiningDaySlotsModel>? days,
    List<DiningBlockedDateModel>? blockedDates,
    bool? isSaving,
    String? error,
  }) {
    return DiningSlotsState(
      days: days ?? this.days,
      blockedDates: blockedDates ?? this.blockedDates,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class DiningSlotsController extends AsyncNotifier<DiningSlotsState> {
  @override
  Future<DiningSlotsState> build() async {
    return _fetch();
  }

  Future<DiningSlotsState> _fetch() async {
    final repo = ref.read(diningRepositoryProvider);
    final data = await repo.getSlots();
    final rawDays = data['days'] as List<DiningDaySlotsModel>? ?? [];
    final blocked = data['blockedDates'] as List<DiningBlockedDateModel>? ?? [];

    List<DiningDaySlotsModel> days;
    if (rawDays.isEmpty) {
      days = buildDefaultDays();
    } else {
      // Ensure all 7 days exist
      final defaultList = buildDefaultDays();
      days = defaultList.map((d) {
        final existing = rawDays.firstWhere(
          (r) => r.dayOfWeek == d.dayOfWeek,
          orElse: () => d,
        );
        return existing;
      }).toList();
    }

    return DiningSlotsState(
      days: days,
      blockedDates: blocked,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  void updateDayOpen(int dayOfWeek, bool isOpen) {
    final current = state.value;
    if (current == null) return;
    final updatedDays = current.days.map((d) {
      if (d.dayOfWeek == dayOfWeek) {
        return d.copyWith(isOpen: isOpen);
      }
      return d;
    }).toList();
    state = AsyncValue.data(current.copyWith(days: updatedDays));
  }

  void addSlot(int dayOfWeek, DiningSlotItemModel slot) {
    final current = state.value;
    if (current == null) return;
    final updatedDays = current.days.map((d) {
      if (d.dayOfWeek == dayOfWeek) {
        final newSlots = [...d.slots, slot];
        return d.copyWith(isOpen: true, slots: newSlots);
      }
      return d;
    }).toList();
    state = AsyncValue.data(current.copyWith(days: updatedDays));
  }

  void updateSlot(int dayOfWeek, int slotIndex, DiningSlotItemModel updatedSlot) {
    final current = state.value;
    if (current == null) return;
    final updatedDays = current.days.map((d) {
      if (d.dayOfWeek == dayOfWeek) {
        final newSlots = List<DiningSlotItemModel>.from(d.slots);
        if (slotIndex >= 0 && slotIndex < newSlots.length) {
          newSlots[slotIndex] = updatedSlot;
        }
        return d.copyWith(slots: newSlots);
      }
      return d;
    }).toList();
    state = AsyncValue.data(current.copyWith(days: updatedDays));
  }

  void removeSlot(int dayOfWeek, int slotIndex) {
    final current = state.value;
    if (current == null) return;
    final updatedDays = current.days.map((d) {
      if (d.dayOfWeek == dayOfWeek) {
        final newSlots = List<DiningSlotItemModel>.from(d.slots)..removeAt(slotIndex);
        return d.copyWith(slots: newSlots);
      }
      return d;
    }).toList();
    state = AsyncValue.data(current.copyWith(days: updatedDays));
  }

  void copyToAllDays(int sourceDayOfWeek) {
    final current = state.value;
    if (current == null) return;
    final source = current.days.firstWhere((d) => d.dayOfWeek == sourceDayOfWeek);
    final updatedDays = current.days.map((d) {
      return d.copyWith(
        isOpen: source.isOpen,
        slots: source.slots.map((s) => s.copyWith()).toList(),
      );
    }).toList();
    state = AsyncValue.data(current.copyWith(days: updatedDays));
  }

  String? validate() {
    final current = state.value;
    if (current == null) return 'No slots to validate';
    for (final day in current.days) {
      if (!day.isOpen) continue;
      if (day.slots.isEmpty) {
        return '${day.day} is open but has no slots added';
      }
      final sorted = [...day.slots]..sort((a, b) => a.startTime.compareTo(b.startTime));
      for (int i = 0; i < sorted.length; i++) {
        if (sorted[i].startTime.compareTo(sorted[i].endTime) >= 0) {
          return '${day.day}: Slot end time must be after start time';
        }
        if (i > 0 && sorted[i].startTime.compareTo(sorted[i - 1].endTime) < 0) {
          return '${day.day}: Slots cannot overlap';
        }
        if (sorted[i].capacity < 0) {
          return '${day.day}: Slot capacity cannot be negative';
        }
      }
    }
    return null;
  }

  Future<bool> saveWeeklySlots() async {
    final validationError = validate();
    if (validationError != null) {
      state = AsyncValue.error(validationError, StackTrace.current);
      return false;
    }

    final current = state.value;
    if (current == null) return false;

    try {
      state = AsyncValue.data(current.copyWith(isSaving: true));
      final repo = ref.read(diningRepositoryProvider);
      final daysPayload = current.days.map((d) => d.toJson()).toList();
      final updatedDays = await repo.saveSlots(daysPayload);
      state = AsyncValue.data(current.copyWith(
        days: updatedDays.isNotEmpty ? updatedDays : current.days,
        isSaving: false,
      ));
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> addBlockedDate(String date, String reason) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      final newBlocked = await repo.addBlockedDate(date, reason);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(
          blockedDates: [newBlocked, ...current.blockedDates],
        ));
      } else {
        await refresh();
      }
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeBlockedDate(String id) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      await repo.removeBlockedDate(id);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(
          blockedDates: current.blockedDates.where((b) => b.id != id).toList(),
        ));
      }
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final diningSlotsControllerProvider =
    AsyncNotifierProvider<DiningSlotsController, DiningSlotsState>(
  DiningSlotsController.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/dining/data/dining_repository.dart';
import 'package:food_user_application/features/dining/domain/dining_table_model.dart';

class DiningTablesState {
  final List<DiningTableModel> tables;
  final DiningTableSummary summary;
  final String activeFilter; // 'all', 'indoor', 'outdoor', etc.

  const DiningTablesState({
    this.tables = const [],
    this.summary = const DiningTableSummary(),
    this.activeFilter = 'all',
  });

  List<DiningTableModel> get filteredTables {
    if (activeFilter == 'all') return tables;
    return tables.where((t) => t.section.toLowerCase() == activeFilter.toLowerCase()).toList();
  }

  DiningTablesState copyWith({
    List<DiningTableModel>? tables,
    DiningTableSummary? summary,
    String? activeFilter,
  }) {
    return DiningTablesState(
      tables: tables ?? this.tables,
      summary: summary ?? this.summary,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class DiningTablesController extends AsyncNotifier<DiningTablesState> {
  @override
  Future<DiningTablesState> build() async {
    return _fetch();
  }

  Future<DiningTablesState> _fetch() async {
    final repo = ref.read(diningRepositoryProvider);
    final res = await repo.listTables();
    final items = res['items'] as List<DiningTableModel>? ?? [];
    final summary = res['summary'] as DiningTableSummary? ??
        DiningTableSummary(
          tables: items.length,
          seats: items.fold(0, (sum, t) => sum + t.seats),
        );
    return DiningTablesState(
      tables: items,
      summary: summary,
      activeFilter: state.value?.activeFilter ?? 'all',
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  void setFilter(String filter) {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(activeFilter: filter));
    }
  }

  Future<bool> createTable({
    required String name,
    required int seats,
    required String section,
    String note = '',
    bool isActive = true,
  }) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      await repo.createTable({
        'name': name,
        'seats': seats,
        'section': section,
        'note': note,
        'isActive': isActive,
      });
      await refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateTable(
    String id, {
    String? name,
    int? seats,
    String? section,
    String? note,
    bool? isActive,
  }) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (seats != null) body['seats'] = seats;
      if (section != null) body['section'] = section;
      if (note != null) body['note'] = note;
      if (isActive != null) body['isActive'] = isActive;

      await repo.updateTable(id, body);
      await refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleActive(DiningTableModel table) async {
    return updateTable(table.id, isActive: !table.isActive);
  }

  Future<bool> deleteTable(String id) async {
    try {
      final repo = ref.read(diningRepositoryProvider);
      await repo.deleteTable(id);
      await refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final diningTablesControllerProvider =
    AsyncNotifierProvider<DiningTablesController, DiningTablesState>(
  DiningTablesController.new,
);

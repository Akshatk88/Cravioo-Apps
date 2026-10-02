import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/complaints/data/complaint_repository.dart';
import 'package:food_user_application/features/complaints/domain/complaint_model.dart';

class ComplaintController extends AsyncNotifier<List<ComplaintModel>> {
  @override
  Future<List<ComplaintModel>> build() {
    return ref.read(complaintRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(complaintRepositoryProvider).list(),
    );
  }
}

final complaintControllerProvider =
    AsyncNotifierProvider<ComplaintController, List<ComplaintModel>>(
      ComplaintController.new,
    );

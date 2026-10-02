import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/support/data/support_repository.dart';
import 'package:food_user_application/features/support/domain/support_ticket_model.dart';

class SupportController extends AsyncNotifier<List<SupportTicketModel>> {
  @override
  Future<List<SupportTicketModel>> build() {
    return ref.read(supportRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(supportRepositoryProvider).list(),
    );
  }

  Future<void> createTicket({
    required String category,
    required String issueType,
    String subject = '',
    String description = '',
    String orderRef = '',
    String priority = 'medium',
  }) async {
    await ref
        .read(supportRepositoryProvider)
        .create(
          category: category,
          issueType: issueType,
          subject: subject,
          description: description,
          orderRef: orderRef,
          priority: priority,
        );
    await refresh();
  }
}

final supportControllerProvider =
    AsyncNotifierProvider<SupportController, List<SupportTicketModel>>(
      SupportController.new,
    );

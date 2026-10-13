import 'package:flutter/material.dart';
import 'package:food_user_application/features/help/presentation/controllers/page_content_controller.dart';
import 'package:food_user_application/features/help/presentation/views/legal_page_screen.dart';

/// Route: `/support-policy`
class SupportPolicyScreen extends StatelessWidget {
  const SupportPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalPageScreen(
    pageKey: PageContentKey.support,
    appBarTitle: 'Support',
  );
}

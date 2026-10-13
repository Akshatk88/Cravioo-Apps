import 'package:flutter/material.dart';
import 'package:food_user_application/features/help/presentation/controllers/page_content_controller.dart';
import 'package:food_user_application/features/help/presentation/views/legal_page_screen.dart';

/// Route: `/privacy-policy`
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalPageScreen(
    pageKey: PageContentKey.privacy,
    appBarTitle: 'Privacy Policy',
  );
}

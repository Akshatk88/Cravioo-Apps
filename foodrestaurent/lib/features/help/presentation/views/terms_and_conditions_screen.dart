import 'package:flutter/material.dart';
import 'package:food_user_application/features/help/presentation/controllers/page_content_controller.dart';
import 'package:food_user_application/features/help/presentation/views/legal_page_screen.dart';

/// Route: `/terms-and-conditions`
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalPageScreen(
    pageKey: PageContentKey.terms,
    appBarTitle: 'Terms & Conditions',
  );
}

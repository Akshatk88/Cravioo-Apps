import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';

/// Mirrors web ConversationListPage.jsx. The web page has no data source
/// (both lists are empty arrays) and the backend has no chat endpoints, so
/// this renders the same search + tabs + empty state.
class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final _search = TextEditingController();
  int _tab = 0; // 0 = Customer, 1 = Delivery Man

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.backgroundDark : AppColors.surfaceLight;
    final text = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final sub =
        dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = dark ? AppColors.borderDark : AppColors.borderLight;
    const tabs = ['Customer', 'Delivery Man'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: sub),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text('Conversation List',
            style: TextStyle(
                color: text, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: text),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: sub),
                suffixIcon: Icon(Icons.search, color: sub),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration:
                  BoxDecoration(border: Border(bottom: BorderSide(color: border))),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: InkWell(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2,
                                color: _tab == i
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            tabs[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _tab == i ? text : sub,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 32, color: sub),
                      const SizedBox(width: 8),
                      Icon(Icons.shopping_bag_outlined, size: 32, color: sub),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tab == 0 ? 'No Customer Found' : 'No Delivery Man Found',
                    style: TextStyle(
                        color: sub, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

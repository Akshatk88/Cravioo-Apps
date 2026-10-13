import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';

/// Mirrors web ChatDetailPage.jsx: header, empty message area
/// ("Chat messages are not available yet.") and a disabled send button.
/// No backend chat API/socket events exist, so nothing is sent or received.
class ChatDetailScreen extends StatelessWidget {
  const ChatDetailScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final sub =
        dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = dark ? AppColors.borderDark : AppColors.borderLight;
    final surface = dark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor:
          dark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: sub),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text('SF',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conversation ${conversationId ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text('Messaging unavailable',
                      style: TextStyle(color: sub, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text('Chat messages are not available yet.',
                  style: TextStyle(color: sub, fontSize: 14)),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: sub),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
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

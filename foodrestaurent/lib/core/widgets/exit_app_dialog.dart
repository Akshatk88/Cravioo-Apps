import 'package:flutter/material.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

class ExitAppDialog extends StatelessWidget {
  const ExitAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top close X button on right
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color:AppColors.primary,
                  ),
                ),
              ),
            ),
            
            // Door exit illustration graphic
            const SizedBox(height: 4),
            _buildExitIllustration(),
            
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'Exit App?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            const Text(
              'Are you sure you want to exit the application?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons Row
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Exit button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:AppColors.primary, // Warm vibrant coral red
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Exit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitIllustration() {
    return SizedBox(
      width: 160,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft peach background circle
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF0EB),
            ),
          ),
          
          // Accent stars/sparkles
          const Positioned(
            left: 18,
            top: 38,
            child: Icon(Icons.star_rate_rounded, size: 14, color: Color(0xFFFFA07A)),
          ),
          const Positioned(
            right: 22,
            top: 42,
            child: Icon(Icons.star_rate_rounded, size: 12, color: Color(0xFFFFA07A)),
          ),
          
          // Door + Arrow illustration
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Door Frame & Panel
              Container(
                width: 52,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                  border: Border.all(color: const Color(0xFF7A1C00), width: 3),
                ),
                child: Stack(
                  children: [
                    // Open Door Panel (Orange-Red)
                    Positioned(
                      left: 2,
                      top: 2,
                      bottom: 2,
                      width: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFED4C2F),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Right Arrow
              const Icon(
                Icons.arrow_forward_rounded,
                size: 34,
                color: Color(0xFFED4C2F),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

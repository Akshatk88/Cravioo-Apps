import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/address_viewmodel.dart';

/// Opens the bottom sheet displaying all saved addresses for the user.
Future<void> showSavedAddressesSheet(BuildContext context) {
  Haptics.light();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const _SavedAddressesModal(),
  );
}

class _SavedAddressesModal extends ConsumerStatefulWidget {
  const _SavedAddressesModal();

  @override
  ConsumerState<_SavedAddressesModal> createState() => _SavedAddressesModalState();
}

class _SavedAddressesModalState extends ConsumerState<_SavedAddressesModal> {
  @override
  void initState() {
    super.initState();
    // Refresh addresses from backend on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressViewModelProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final savedAddresses = ref.watch(addressViewModelProvider);
    final isLoggedIn = ref.watch(authViewModelProvider).value != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
              width: 44.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (savedAddresses.isNotEmpty) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${savedAddresses.length}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22.sp, color: secondaryColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: !isLoggedIn
                ? Padding(
                    padding: EdgeInsets.all(28.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 48.sp, color: secondaryColor),
                        SizedBox(height: 12.h),
                        Text(
                          'Log in to view saved addresses',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.addAddress)}');
                          },
                          child: const Text('Log In', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : (ref.watch(addressViewModelProvider.notifier).isLoading && savedAddresses.isEmpty)
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 48.h),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : savedAddresses.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_off_outlined,
                                size: 40.sp,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No Saved Addresses Yet',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Add your home, work, or other addresses for swift delivery.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13.sp, color: secondaryColor),
                            ),
                            SizedBox(height: 20.h),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                context.push(RouteNames.addAddress);
                              },
                              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                              label: const Text('Add Address Now', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        shrinkWrap: true,
                        itemCount: savedAddresses.length,
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (ctx, index) {
                          final addr = savedAddresses[index];
                          final isHome = addr.type.toLowerCase() == 'home';
                          final isWork = addr.type.toLowerCase() == 'office' || addr.type.toLowerCase() == 'work';
                          final typeIcon = isHome
                              ? Icons.home_rounded
                              : (isWork ? Icons.work_rounded : Icons.location_on_rounded);
                          final iconColor = isHome
                              ? const Color(0xFFFF6D00)
                              : (isWork ? const Color(0xFF2979FF) : const Color(0xFF00C853));

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF282828) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: addr.isDefault
                                    ? AppColors.primary
                                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                                width: addr.isDefault ? 1.5 : 1.0,
                              ),
                            ),
                            padding: EdgeInsets.all(14.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8.r),
                                      decoration: BoxDecoration(
                                        color: iconColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Icon(typeIcon, color: iconColor, size: 20.sp),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  addr.title.isNotEmpty ? addr.title : addr.type,
                                                  style: TextStyle(
                                                    fontSize: 15.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (addr.isDefault) ...[
                                                SizedBox(width: 8.w),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6.r),
                                                  ),
                                                  child: Text(
                                                    'DEFAULT',
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            addr.fullAddress,
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: secondaryColor,
                                              height: 1.3,
                                            ),
                                          ),
                                          if (addr.contactPhone != null && addr.contactPhone!.isNotEmpty) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              'Phone: ${addr.contactPhone}',
                                              style: TextStyle(
                                                fontSize: 11.5.sp,
                                                color: secondaryColor.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Delete button
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, size: 20.sp, color: Colors.red[400]),
                                      tooltip: 'Delete address',
                                      onPressed: () async {
                                        Haptics.light();
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                            title: const Text('Delete Address'),
                                            content: const Text('Are you sure you want to remove this address?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogCtx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                                ),
                                                onPressed: () => Navigator.pop(dialogCtx, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          final deleted = await ref.read(addressViewModelProvider.notifier).deleteAddress(addr.id);
                                          if (deleted && context.mounted) {
                                            AppSnackbar.success(context, 'Address deleted.');
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                if (!addr.isDefault) ...[
                                  SizedBox(height: 10.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () async {
                                          Haptics.light();
                                          await ref.read(addressViewModelProvider.notifier).setDefaultAddress(addr.id);
                                          if (context.mounted) {
                                            AppSnackbar.success(context, 'Default address updated.');
                                          }
                                        },
                                        icon: Icon(Icons.check_circle_outline_rounded, size: 15.sp, color: AppColors.primary),
                                        label: Text(
                                          'Set as Default',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom "+ Add New Address" Button
          if (isLoggedIn && savedAddresses.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(RouteNames.addAddress);
                    },
                    icon: Icon(Icons.add_location_alt_rounded, size: 20.sp, color: Colors.white),
                    label: Text(
                      '+ Add New Address',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

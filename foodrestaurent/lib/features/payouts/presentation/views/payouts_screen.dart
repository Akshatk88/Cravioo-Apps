import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/finance/domain/finance_model.dart';
import 'package:food_user_application/features/finance/domain/subscription_invoice_model.dart';
import 'package:food_user_application/features/finance/domain/withdrawal_model.dart';
import 'package:food_user_application/features/finance/presentation/controllers/finance_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key, this.initialTab = 'invoices'});

  final String initialTab;

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  late bool _isPayoutsTab = widget.initialTab == 'payouts';

  // ============================================================
  // APP THEME COLORS
  // ============================================================

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _background(bool dark) {
    return dark ? AppColors.backgroundDark : AppColors.backgroundLight;
  }

  Color _surface(bool dark) {
    return dark ? AppColors.surfaceDark : AppColors.surfaceLight;
  }


  Color _primaryText(bool dark) {
    return dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  }

  Color _secondaryText(bool dark) {
    return dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  }

  Color _border(bool dark) {
    return dark ? AppColors.borderDark : AppColors.borderLight;
  }

  Color _primary(bool dark) {
    return dark ? AppColors.primaryLight : AppColors.primaryButton;
  }

  Color _primaryTint(bool dark) {
    return dark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primaryTint;
  }

  Color _walletBackground(bool dark) {
    return dark ? AppColors.surfaceVariantDark : AppColors.primaryButton;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);

    return Scaffold(
      backgroundColor: _background(dark),
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context, dark),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopTabs(context, dark),

              const SizedBox(height: 16),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isPayoutsTab
                    ? _buildPayoutsView(context, dark)
                    : _buildInvoicesView(context, dark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(BuildContext context, bool dark) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;

    final displayId = restaurant != null
        ? (restaurant.restaurantId.isNotEmpty
              ? restaurant.restaurantId
              : restaurant.id.isNotEmpty
              ? restaurant.id.substring(0, restaurant.id.length.clamp(0, 6))
              : '--')
        : '--';

    return AppBar(
      backgroundColor: _background(dark),
      foregroundColor: _primaryText(dark),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 96,
      leadingWidth: 58,

      leading: Builder(
        builder: (context) {
          return IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: Icon(Icons.menu_rounded, size: 29, color: _primaryText(dark)),
          );
        },
      ),

      titleSpacing: 0,

      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            restaurant?.restaurantName ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryText(dark),
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ID: $displayId',
                style: TextStyle(
                  color: _secondaryText(dark),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(width: 5),

              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _primary(dark),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 4),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primaryTint(dark),
              shape: BoxShape.circle,
              border: Border.all(color: _primary(dark).withValues(alpha: 0.2)),
            ),
            child: Icon(
              _isPayoutsTab
                  ? Icons.account_balance_wallet_rounded
                  : Icons.calculate_rounded,
              color: _primary(dark),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TOP TABS
  // ============================================================

  Widget _buildTopTabs(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Payouts',
              icon: Icons.account_balance_wallet_outlined,
              isSelected: _isPayoutsTab,
              dark: dark,
              onTap: () {
                setState(() {
                  _isPayoutsTab = true;
                });
              },
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: _buildTabButton(
              label: 'Invoices & Taxes',
              icon: Icons.receipt_long_outlined,
              isSelected: !_isPayoutsTab,
              dark: dark,
              onTap: () {
                setState(() {
                  _isPayoutsTab = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool dark,
    required VoidCallback onTap,
  }) {
    final surface = _surface(dark);
    final primaryText = _primaryText(dark);
    final secondaryText = _secondaryText(dark);
    final border = _border(dark);
    final primary = _primary(dark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryButton : surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.primaryButton : border,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : secondaryText,
              ),

              const SizedBox(width: 4),

              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : primaryText,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INVOICES
  // ============================================================

  Widget _buildInvoicesView(BuildContext context, bool dark) {
    final financeAsync = ref.watch(financeControllerProvider);

    return financeAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(45),
        child: Center(
          child: CircularProgressIndicator(
            color: _primary(dark),
            strokeWidth: 2.5,
          ),
        ),
      ),

      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _buildErrorBox(
          dark,
          error is ApiException
              ? error.message
              : 'Failed to load finance data.',
        ),
      ),

      data: (finance) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInvoiceSummaryCard(finance, dark),

              if (finance.subscriptionDueAmount > 0) ...[
                const SizedBox(height: 14),

                _buildSubscriptionDueCard(finance, dark),
              ],

              const SizedBox(height: 18),

              _buildOrderInvoiceCard(context, finance, dark),

              _buildSubscriptionInvoicesSection(context, dark),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // INVOICE SUMMARY
  // ============================================================

  Widget _buildInvoiceSummaryCard(FinanceModel finance, bool dark) {
    final primaryText = _primaryText(dark);
    final secondaryText = _secondaryText(dark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _primaryTint(dark),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: _primary(dark),
                  size: 26,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoices & Taxes',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Overview of your earnings & taxes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _buildSummaryGridItem(
                  title: 'Orders',
                  value: '${finance.invoiceCount}',
                  icon: Icons.shopping_bag_outlined,
                  iconColor: _primary(dark),
                  dark: dark,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildSummaryGridItem(
                  title: 'Subtotal',
                  value: '₹${finance.invoiceSubtotal.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.success,
                  dark: dark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildSummaryGridItem(
                  title: 'Taxes',
                  value: '₹${finance.invoiceTaxes.toStringAsFixed(2)}',
                  icon: Icons.receipt_outlined,
                  iconColor: _primary(dark),
                  dark: dark,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildSummaryGridItem(
                  title: 'Gross amount',
                  value: '₹${finance.invoiceGross.toStringAsFixed(2)}',
                  icon: Icons.monetization_on_outlined,
                  iconColor: _primary(dark),
                  dark: dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGridItem({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool dark,
  }) {
    final background = _background(dark);
    final primaryText = _primaryText(dark);
    final secondaryText = _secondaryText(dark);
    final border = _border(dark);

    return Container(
      height: 126,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border, width: 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -5,
            bottom: -7,
            child: Icon(
              icon,
              size: 60,
              color: iconColor.withValues(alpha: 0.10),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),

              const Spacer(),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBSCRIPTION DUE
  // ============================================================

  Widget _buildSubscriptionDueCard(FinanceModel finance, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _surface(dark),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 21,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Subscription due: '
              '₹${finance.subscriptionDueAmount.toStringAsFixed(2)}'
              '${finance.lockedMonths.isNotEmpty ? ' (${finance.lockedMonths})' : ''}',
              style: TextStyle(
                color: _primaryText(dark),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER INVOICE
  // ============================================================

  Widget _buildOrderInvoiceCard(
    BuildContext context,
    FinanceModel finance,
    bool dark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSmallIcon(Icons.receipt_long_outlined, dark),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  'Order invoice details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primaryText(dark),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (finance.orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No orders yet.',
                  style: TextStyle(color: _secondaryText(dark), fontSize: 12.5),
                ),
              ),
            )
          else
            for (var i = 0; i < finance.orders.length; i++) ...[
              _buildInvoiceDetailRow(context, finance.orders[i], dark),

              if (i < finance.orders.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailRow(
    BuildContext context,
    FinanceOrderRow order,
    bool dark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/order-details/${order.orderId}');
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _background(dark),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _border(dark), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primaryTint(dark),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: _primary(dark),
                  size: 19,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order: ${order.orderId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryText(dark),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.paymentMethod,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _secondaryText(dark),
                              fontSize: 10.5,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '|',
                            style: TextStyle(color: _border(dark)),
                          ),
                        ),

                        Flexible(
                          child: Text(
                            order.orderStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 7),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _primaryText(dark),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: _secondaryText(dark),
                          fontSize: 9.5,
                        ),
                      ),

                      const SizedBox(width: 1),

                      Icon(
                        Icons.chevron_right,
                        color: _secondaryText(dark),
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUBSCRIPTION INVOICES
  // ============================================================

  Widget _buildSubscriptionInvoicesSection(BuildContext context, bool dark) {
    final invoicesAsync = ref.watch(subscriptionInvoicesControllerProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription invoices',
            style: TextStyle(
              color: _primaryText(dark),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 11),

          invoicesAsync.when(
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _primary(dark)),
              ),
            ),

            error: (error, _) => Text(
              error is ApiException
                  ? error.message
                  : 'Failed to load subscription invoices.',
              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
            ),

            data: (invoices) {
              if (invoices.isEmpty) {
                return Text(
                  'No subscription invoices yet.',
                  style: TextStyle(color: _secondaryText(dark), fontSize: 12.5),
                );
              }

              return Column(
                children: [
                  for (final invoice in invoices) ...[
                    _buildSubscriptionInvoiceRow(context, invoice, dark),

                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionInvoiceRow(
    BuildContext context,
    SubscriptionInvoiceModel invoice,
    bool dark,
  ) {
    final statusColor = switch (invoice.status) {
      'settled' => AppColors.success,
      'partially_settled' => _primary(dark),
      'waived' => _secondaryText(dark),
      _ => _primary(dark),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(dark), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: _primaryTint(dark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: _primary(dark),
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.billingMonthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primaryText(dark),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  invoice.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _secondaryText(dark), fontSize: 10.5),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${invoice.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _primaryText(dark),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),

              const SizedBox(height: 4),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  invoice.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYOUTS VIEW
  // ============================================================

  Widget _buildPayoutsView(BuildContext context, bool dark) {
    final financeAsync = ref.watch(financeControllerProvider);

    final withdrawalsAsync = ref.watch(withdrawalsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Wallet balance',
            style: TextStyle(
              color: _primaryText(dark),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(height: 10),

        financeAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: _primary(dark)),
            ),
          ),

          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildErrorBox(
              dark,
              error is ApiException ? error.message : 'Failed to load wallet.',
            ),
          ),

          data: (finance) {
            return _buildWalletCard(context, finance, dark);
          },
        ),

        const SizedBox(height: 21),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Withdrawal requests',
                  style: TextStyle(
                    color: _primaryText(dark),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              _buildFilterButton(dark),
            ],
          ),
        ),

        const SizedBox(height: 10),

        withdrawalsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: _primary(dark)),
            ),
          ),

          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildErrorBox(
              dark,
              error is ApiException
                  ? error.message
                  : 'Failed to load withdrawal requests.',
            ),
          ),

          data: (withdrawals) {
            return withdrawals.isEmpty
                ? _buildEmptyWithdrawals(dark)
                : _buildRequestsList(context, withdrawals, dark);
          },
        ),
      ],
    );
  }


  // ============================================================
  // WALLET CARD
  // ============================================================

  Widget _buildWalletCard(
    BuildContext context,
    FinanceModel finance,
    bool dark,
  ) {
    final walletColor = _walletBackground(dark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: walletColor,
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: _primary(dark).withValues(alpha: dark ? 0.18 : 0.14),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -35,
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 145,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Available to withdraw',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹ ${finance.netAvailable.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                if (finance.lockedAmount > 0) ...[
                  const SizedBox(height: 6),

                  Text(
                    '₹${finance.lockedAmount.toStringAsFixed(2)} '
                    'locked against subscription dues'
                    '${finance.lockedMonths.isNotEmpty ? ' (${finance.lockedMonths})' : ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _showWithdrawDialog(context, finance.netAvailable, dark);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, size: 19),

                        SizedBox(width: 8),

                        Text(
                          'Withdraw',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        SizedBox(width: 4),

                        Icon(Icons.chevron_right, size: 19),
                      ],
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

  // ============================================================
  // FILTER
  // ============================================================

  Widget _buildFilterButton(bool dark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          // Filter action can be connected later.
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: _surface(dark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border(dark)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_outlined, size: 15, color: _primary(dark)),

              const SizedBox(width: 5),

              Text(
                'Filter',
                style: TextStyle(
                  color: _primaryText(dark),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY WITHDRAWALS
  // ============================================================

  Widget _buildEmptyWithdrawals(bool dark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: _cardDecoration(dark),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primaryTint(dark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: _primary(dark),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'No withdrawal requests yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryText(dark),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Your withdrawal history will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryText(dark), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WITHDRAWAL REQUESTS
  // ============================================================

  Widget _buildRequestsList(
    BuildContext context,
    List<WithdrawalModel> withdrawals,
    bool dark,
  ) {
    final dateFormat = DateFormat('d MMM yyyy • h:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        decoration: _cardDecoration(dark),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: withdrawals.length,
          separatorBuilder: (_, _) {
            return Divider(
              height: 1,
              color: _border(dark).withValues(alpha: 0.7),
            );
          },
          itemBuilder: (context, index) {
            final withdrawal = withdrawals[index];

            final isPending = withdrawal.status == 'pending';

            final isRejected = withdrawal.status == 'rejected';

            final statusColor = isRejected
                ? AppColors.error
                : isPending
                ? _primary(dark)
                : AppColors.success;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 41,
                    height: 41,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPending
                          ? Icons.pending_actions
                          : isRejected
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      color: statusColor,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Withdrawal to Bank',
                          style: TextStyle(
                            color: _primaryText(dark),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          dateFormat.format(withdrawal.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _secondaryText(dark),
                            fontSize: 9.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 7),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '- ₹ ${withdrawal.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _primaryText(dark),
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        withdrawal.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // WITHDRAW DIALOG
  // ============================================================

  Future<void> _showWithdrawDialog(
    BuildContext context,
    double netAvailable,
    bool dark,
  ) async {
    final amountController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface(dark),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          title: Text(
            'Withdraw funds',
            style: TextStyle(
              color: _primaryText(dark),
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _primaryTint(dark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Available: '
                  '₹${netAvailable.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: _primaryText(dark),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: TextStyle(
                  color: _primaryText(dark),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(
                    color: _secondaryText(dark),
                    fontSize: 13,
                  ),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    color: _primaryText(dark),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: _background(dark),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _border(dark)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _primary(dark), width: 1.4),
                  ),
                ),
              ),
            ],
          ),

          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _secondaryText(dark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());

                Navigator.pop(dialogContext, amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Withdraw',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    amountController.dispose();

    if (result == null) return;

    if (!context.mounted) return;

    if (result <= 0) {
      _showSnack(context, 'Enter a valid amount.', isError: true);
      return;
    }

    if (result > netAvailable) {
      _showSnack(
        context,
        'Amount exceeds your available balance of '
        '₹${netAvailable.toStringAsFixed(2)}.',
        isError: true,
      );
      return;
    }

    final restaurant = ref.read(restaurantProfileControllerProvider).value;

    try {
      await ref
          .read(withdrawalsControllerProvider.notifier)
          .requestWithdrawal(
            amount: result,
            bankDetails: {
              'accountNumber': restaurant?.accountNumber ?? '',
              'ifscCode': restaurant?.ifscCode ?? '',
              'accountHolderName': restaurant?.accountHolderName ?? '',
            },
          );

      if (context.mounted) {
        _showSnack(context, 'Withdrawal request submitted.');
      }
    } catch (e) {
      if (context.mounted) {
        final message = e is ApiException
            ? e.message
            : 'Failed to submit withdrawal request.';

        _showSnack(context, message, isError: true);
      }
    }
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  BoxDecoration _cardDecoration(bool dark) {
    return BoxDecoration(
      color: _surface(dark),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border(dark), width: 1.1),
      boxShadow: [
        if (!dark)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
      ],
    );
  }

  // ============================================================
  // SMALL ICON
  // ============================================================

  Widget _buildSmallIcon(IconData icon, bool dark) {
    return Container(
      width: 41,
      height: 41,
      decoration: BoxDecoration(
        color: _primaryTint(dark),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: _primary(dark), size: 21),
    );
  }

  // ============================================================
  // ERROR BOX
  // ============================================================

  Widget _buildErrorBox(bool dark, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.errorLight,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 12.5),
      ),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final dark = _isDark(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : dark
            ? AppColors.surfaceVariantDark
            : AppColors.primaryButton,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

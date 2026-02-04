import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/loading_overlay.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  DashboardData? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // TODO: Replace with actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _dashboardData = DashboardData.sample();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading && _dashboardData == null,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 120.h,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'CLIO',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      // TODO: Navigate to notifications
                    },
                  ),
                  SizedBox(width: 8.w),
                ],
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Card - Next Due Bill
                      if (_dashboardData?.nextDueBill != null)
                        _NextDueCard(bill: _dashboardData!.nextDueBill!),
                      
                      SizedBox(height: AppSpacing.sectionSpacing),
                      
                      // Summary Stats
                      _SummaryStats(
                        totalDue: _dashboardData?.totalDue ?? 0,
                        upcomingCount: _dashboardData?.upcomingBills.length ?? 0,
                      ),
                      
                      SizedBox(height: AppSpacing.sectionSpacing),
                      
                      // Upcoming Bills Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Upcoming Bills',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: View all bills
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      
                      // Bills List
                      if (_dashboardData?.upcomingBills.isEmpty ?? true)
                        _EmptyBillsState(onAddCard: _showAddCardSheet)
                      else
                        ..._dashboardData!.upcomingBills.map((bill) => 
                          _BillCard(bill: bill)
                        ),
                      
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      builder: (context) => const _AddCardSheet(),
    );
  }
}

/// Hero card showing the next due bill
class _NextDueCard extends StatelessWidget {
  final UpcomingBill bill;

  const _NextDueCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final daysUntil = bill.dueDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntil <= 3;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUrgent
              ? [AppColors.error, AppColors.error.withOpacity(0.8)]
              : [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? AppColors.error : AppColors.primary).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150.w,
                height: 150.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppBorderRadius.circular),
                        ),
                        child: Text(
                          daysUntil == 0
                              ? 'Due Today'
                              : daysUntil == 1
                                  ? 'Due Tomorrow'
                                  : 'Due in $daysUntil days',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _BankLogo(bankName: bill.bankName, isLight: true),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    bill.cardName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '•••• ${bill.lastFourDigits}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount Due',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '\$${bill.amountDue.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to payment
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: isUrgent ? AppColors.error : AppColors.primary,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.h,
                          ),
                        ),
                        child: const Text('Pay Now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary statistics row
class _SummaryStats extends StatelessWidget {
  final double totalDue;
  final int upcomingCount;

  const _SummaryStats({
    required this.totalDue,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Due',
            value: '\$${totalDue.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _StatCard(
            label: 'Upcoming',
            value: '$upcomingCount',
            icon: Icons.calendar_today,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20.w,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual bill card
class _BillCard extends StatelessWidget {
  final UpcomingBill bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final daysUntil = bill.dueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntil < 0;
    final isUrgent = daysUntil <= 3 && daysUntil >= 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 8.h,
        ),
        leading: _BankLogo(bankName: bill.bankName),
        title: Text(
          bill.cardName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '•••• ${bill.lastFourDigits}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${bill.amountDue.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isOverdue
                    ? AppColors.error.withOpacity(0.1)
                    : isUrgent
                        ? AppColors.warning.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Text(
                isOverdue
                    ? '${-daysUntil} days overdue'
                    : daysUntil == 0
                        ? 'Today'
                        : '$daysUntil days',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isOverdue
                      ? AppColors.error
                      : isUrgent
                          ? AppColors.warning
                          : AppColors.success,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to bill details
        },
      ),
    );
  }
}

/// Empty state when no bills
class _EmptyBillsState extends StatelessWidget {
  final VoidCallback onAddCard;

  const _EmptyBillsState({required this.onAddCard});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 40.h),
          Icon(
            Icons.credit_card_outlined,
            size: 64.w,
            color: AppColors.lightTextSecondary.withOpacity(0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'No bills yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add your first credit card to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onAddCard,
            icon: const Icon(Icons.add),
            label: const Text('Add Card'),
          ),
        ],
      ),
    );
  }
}

/// Bank logo widget
class _BankLogo extends StatelessWidget {
  final String bankName;
  final bool isLight;

  const _BankLogo({
    required this.bankName,
    this.isLight = false,
  });

  Color _getBankColor() {
    switch (bankName.toLowerCase()) {
      case 'ctbc':
        return AppColors.ctbc;
      case 'cathay united bank':
        return AppColors.cathay;
      case 'taishin bank':
        return AppColors.taishin;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: _getBankColor().withOpacity(isLight ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Center(
        child: Text(
          bankName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: isLight ? Colors.white : _getBankColor(),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding cards
class _AddCardSheet extends StatelessWidget {
  const _AddCardSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Add Credit Card',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8.h),
          Text(
            'Choose how you want to add your card',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 24.h),
          _AddCardOption(
            icon: Icons.camera_alt_outlined,
            title: 'Scan Statement',
            subtitle: 'Upload or take a photo of your statement',
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Navigate to upload screen
            },
          ),
          SizedBox(height: 12.h),
          _AddCardOption(
            icon: Icons.credit_card_outlined,
            title: 'Enter Manually',
            subtitle: 'Add card details manually',
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Navigate to manual entry
            },
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}

class _AddCardOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddCardOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightBorder),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// Data Models

class DashboardData {
  final UpcomingBill? nextDueBill;
  final double totalDue;
  final List<UpcomingBill> upcomingBills;

  DashboardData({
    this.nextDueBill,
    required this.totalDue,
    required this.upcomingBills,
  });

  factory DashboardData.sample() {
    final bills = [
      UpcomingBill(
        id: '1',
        cardName: 'Cash Back Card',
        bankName: 'CTBC',
        lastFourDigits: '4521',
        amountDue: 2580.50,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        statementDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
      UpcomingBill(
        id: '2',
        cardName: 'Platinum Card',
        bankName: 'Cathay United Bank',
        lastFourDigits: '8934',
        amountDue: 1245.00,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        statementDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      UpcomingBill(
        id: '3',
        cardName: 'Rewards Card',
        bankName: 'Taishin Bank',
        lastFourDigits: '2215',
        amountDue: 890.25,
        dueDate: DateTime.now().add(const Duration(days: 12)),
        statementDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    return DashboardData(
      nextDueBill: bills.first,
      totalDue: bills.fold(0, (sum, bill) => sum + bill.amountDue),
      upcomingBills: bills,
    );
  }
}

class UpcomingBill {
  final String id;
  final String cardName;
  final String bankName;
  final String lastFourDigits;
  final double amountDue;
  final DateTime dueDate;
  final DateTime statementDate;

  UpcomingBill({
    required this.id,
    required this.cardName,
    required this.bankName,
    required this.lastFourDigits,
    required this.amountDue,
    required this.dueDate,
    required this.statementDate,
  });
}

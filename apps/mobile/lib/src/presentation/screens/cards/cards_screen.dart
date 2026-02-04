import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/loading_overlay.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  bool _isLoading = true;
  List<CreditCard> _cards = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    // TODO: Replace with actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _cards = CreditCard.sampleCards();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await _loadCards();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading && _cards.isEmpty,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100.h,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'My Cards',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total cards summary
                      _CardsSummary(cards: _cards),
                      SizedBox(height: 24.h),
                      
                      // Cards list header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Cards',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          TextButton.icon(
                            onPressed: _showAddCardOptions,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
              
              // Cards list
              if (_cards.isEmpty)
                SliverFillRemaining(
                  child: _EmptyCardsState(onAddCard: _showAddCardOptions),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CreditCardItem(
                        card: _cards[index],
                        onTap: () => _showCardDetails(_cards[index]),
                      ),
                      childCount: _cards.length,
                    ),
                  ),
                ),
              
              SliverPadding(
                padding: EdgeInsets.all(AppSpacing.screenPadding),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddCardOptions,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddCardOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      builder: (context) => const _AddCardBottomSheet(),
    );
  }

  void _showCardDetails(CreditCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      builder: (context) => _CardDetailsSheet(card: card),
    );
  }
}

/// Cards summary widget
class _CardsSummary extends StatelessWidget {
  final List<CreditCard> cards;

  const _CardsSummary({required this.cards});

  @override
  Widget build(BuildContext context) {
    final totalCreditLimit = cards.fold<double>(
      0, 
      (sum, card) => sum + card.creditLimit,
    );
    final totalBalance = cards.fold<double>(
      0, 
      (sum, card) => sum + card.currentBalance,
    );
    final availableCredit = totalCreditLimit - totalBalance;

    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Total Cards',
              value: '${cards.length}',
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: AppColors.lightBorder,
          ),
          Expanded(
            child: _SummaryItem(
              label: 'Total Limit',
              value: '\$${_formatAmount(totalCreditLimit)}',
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: AppColors.lightBorder,
          ),
          Expanded(
            child: _SummaryItem(
              label: 'Available',
              value: '\$${_formatAmount(availableCredit)}',
              valueColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Credit card list item
class _CreditCardItem extends StatelessWidget {
  final CreditCard card;
  final VoidCallback onTap;

  const _CreditCardItem({
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final utilizationPercent = card.currentBalance / card.creditLimit;
    final isHighUtilization = utilizationPercent > 0.8;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BankLogo(bankName: card.bankName),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.cardName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '•••• ${card.lastFourDigits}',
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
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Balance',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '\$${card.currentBalance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Available',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '\$${(card.creditLimit - card.currentBalance).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Utilization bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: utilizationPercent,
                  backgroundColor: AppColors.lightSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isHighUtilization ? AppColors.error : AppColors.success,
                  ),
                  minHeight: 6.h,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(utilizationPercent * 100).toStringAsFixed(0)}% utilized',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isHighUtilization ? AppColors.error : AppColors.lightTextSecondary,
                    ),
                  ),
                  Text(
                    'Limit: \$${card.creditLimit.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bank logo widget
class _BankLogo extends StatelessWidget {
  final String bankName;

  const _BankLogo({required this.bankName});

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
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: _getBankColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Center(
        child: Text(
          bankName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: _getBankColor(),
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
      ),
    );
  }
}

/// Empty state
class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onAddCard;

  const _EmptyCardsState({required this.onAddCard});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.credit_card_outlined,
              size: 60.w,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No cards yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8.h),
          Text(
            'Add your first credit card to start tracking bills',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onAddCard,
            icon: const Icon(Icons.add),
            label: const Text('Add Credit Card'),
          ),
        ],
      ),
    );
  }
}

/// Add card bottom sheet
class _AddCardBottomSheet extends StatelessWidget {
  const _AddCardBottomSheet();

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
          _OptionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Scan Statement',
            subtitle: 'Upload or take a photo of your statement',
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Navigate to upload
            },
          ),
          SizedBox(height: 12.h),
          _OptionTile(
            icon: Icons.edit_outlined,
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

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
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
              child: Icon(icon, color: AppColors.primary),
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

/// Card details bottom sheet
class _CardDetailsSheet extends StatelessWidget {
  final CreditCard card;

  const _CardDetailsSheet({required this.card});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.all(AppSpacing.screenPadding),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
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
                // Card header
                Row(
                  children: [
                    _BankLogo(bankName: card.bankName),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.cardName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '•••• ${card.lastFourDigits}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),
                // Stats grid
                _DetailGrid(card: card),
                SizedBox(height: 32.h),
                // Actions
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16.h),
                _ActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'View Statements',
                  onTap: () {
                    // TODO: Navigate to statements
                  },
                ),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Card Details',
                  onTap: () {
                    // TODO: Edit card
                  },
                ),
                _ActionTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notification Settings',
                  onTap: () {
                    // TODO: Notification settings
                  },
                ),
                _ActionTile(
                  icon: Icons.delete_outline,
                  title: 'Remove Card',
                  color: AppColors.error,
                  onTap: () {
                    // TODO: Remove card confirmation
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final CreditCard card;

  const _DetailGrid({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DetailItem(
                label: 'Credit Limit',
                value: '\$${card.creditLimit.toStringAsFixed(2)}',
              ),
            ),
            Expanded(
              child: _DetailItem(
                label: 'Current Balance',
                value: '\$${card.currentBalance.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _DetailItem(
                label: 'Available Credit',
                value: '\$${(card.creditLimit - card.currentBalance).toStringAsFixed(2)}',
                valueColor: AppColors.success,
              ),
            ),
            Expanded(
              child: _DetailItem(
                label: 'Next Due Date',
                value: card.nextDueDate != null
                    ? '${card.nextDueDate!.day}/${card.nextDueDate!.month}'
                    : 'N/A',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Models

class CreditCard {
  final String id;
  final String cardName;
  final String bankName;
  final String lastFourDigits;
  final double creditLimit;
  final double currentBalance;
  final DateTime? nextDueDate;

  CreditCard({
    required this.id,
    required this.cardName,
    required this.bankName,
    required this.lastFourDigits,
    required this.creditLimit,
    required this.currentBalance,
    this.nextDueDate,
  });

  static List<CreditCard> sampleCards() {
    return [
      CreditCard(
        id: '1',
        cardName: 'Cash Back Card',
        bankName: 'CTBC',
        lastFourDigits: '4521',
        creditLimit: 50000,
        currentBalance: 12580.50,
        nextDueDate: DateTime.now().add(const Duration(days: 5)),
      ),
      CreditCard(
        id: '2',
        cardName: 'Platinum Card',
        bankName: 'Cathay United Bank',
        lastFourDigits: '8934',
        creditLimit: 100000,
        currentBalance: 24500.00,
        nextDueDate: DateTime.now().add(const Duration(days: 12)),
      ),
      CreditCard(
        id: '3',
        cardName: 'Rewards Card',
        bankName: 'Taishin Bank',
        lastFourDigits: '2215',
        creditLimit: 30000,
        currentBalance: 5890.25,
        nextDueDate: DateTime.now().add(const Duration(days: 18)),
      ),
    ];
  }
}

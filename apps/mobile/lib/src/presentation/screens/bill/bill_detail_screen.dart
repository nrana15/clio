import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';

/// Bill detail model
class BillDetail {
  final String id;
  final String cardId;
  final String cardName;
  final String bankName;
  final String lastFourDigits;
  final String? cardColor;
  
  final DateTime statementDate;
  final DateTime dueDate;
  final double totalAmount;
  final double? minimumDue;
  final String currency;
  
  final String status; // pending_review, unpaid, paid_confirmed
  final double confidenceScore;
  final bool requiresReview;
  
  final DateTime? paidConfirmedAt;
  final String? reviewNotes;

  BillDetail({
    required this.id,
    required this.cardId,
    required this.cardName,
    required this.bankName,
    required this.lastFourDigits,
    this.cardColor,
    required this.statementDate,
    required this.dueDate,
    required this.totalAmount,
    this.minimumDue,
    this.currency = 'TWD',
    required this.status,
    required this.confidenceScore,
    this.requiresReview = false,
    this.paidConfirmedAt,
    this.reviewNotes,
  });

  bool get isPaid => status == 'paid_confirmed';
  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  factory BillDetail.fromJson(Map<String, dynamic> json) {
    return BillDetail(
      id: json['id'],
      cardId: json['card_id'],
      cardName: json['card']['display_name'] ?? 'Unknown Card',
      bankName: json['card']['issuer_bank'] ?? 'Unknown',
      lastFourDigits: json['card']['last_four'] ?? '0000',
      cardColor: json['card']['card_color'],
      statementDate: DateTime.parse(json['statement_date']),
      dueDate: DateTime.parse(json['due_date']),
      totalAmount: double.parse(json['total_amount_due'].toString()),
      minimumDue: json['minimum_due'] != null 
          ? double.parse(json['minimum_due'].toString()) 
          : null,
      currency: json['currency'] ?? 'TWD',
      status: json['status'],
      confidenceScore: json['extraction_confidence']?.toDouble() ?? 0.0,
      requiresReview: json['requires_review'] ?? false,
      paidConfirmedAt: json['paid_confirmed_at'] != null 
          ? DateTime.parse(json['paid_confirmed_at']) 
          : null,
      reviewNotes: json['review_notes'],
    );
  }
}

class BillDetailScreen extends StatefulWidget {
  final String billId;
  
  const BillDetailScreen({
    super.key,
    required this.billId,
  });

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  bool _isLoading = true;
  bool _isConfirming = false;
  BillDetail? _bill;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    setState(() => _isLoading = true);
    
    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Sample data for development
      _bill = BillDetail(
        id: widget.billId,
        cardId: 'card-1',
        cardName: 'Cash Back Card',
        bankName: 'CTBC',
        lastFourDigits: '4521',
        cardColor: '#1E3A8A',
        statementDate: DateTime.now().subtract(const Duration(days: 5)),
        dueDate: DateTime.now().add(const Duration(days: 2)),
        totalAmount: 2580.50,
        minimumDue: 500.00,
        status: 'unpaid',
        confidenceScore: 0.95,
        requiresReview: false,
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bill details';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmPaid() async {
    setState(() => _isConfirming = true);
    
    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _bill = BillDetail(
          id: _bill!.id,
          cardId: _bill!.cardId,
          cardName: _bill!.cardName,
          bankName: _bill!.bankName,
          lastFourDigits: _bill!.lastFourDigits,
          cardColor: _bill!.cardColor,
          statementDate: _bill!.statementDate,
          dueDate: _bill!.dueDate,
          totalAmount: _bill!.totalAmount,
          minimumDue: _bill!.minimumDue,
          currency: _bill!.currency,
          status: 'paid_confirmed',
          confidenceScore: _bill!.confidenceScore,
          requiresReview: _bill!.requiresReview,
          paidConfirmedAt: DateTime.now(),
        );
        _isConfirming = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isConfirming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm payment'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConfirmPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Are you sure you want to mark this bill of \$${_bill!.totalAmount.toStringAsFixed(2)} as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmPaid();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Bill Details'),
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        actions: [
          if (_bill != null && !_bill!.isPaid)
            TextButton.icon(
              onPressed: _showConfirmPaymentDialog,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark Paid'),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _errorMessage != null
            ? _ErrorState(
                message: _errorMessage!,
                onRetry: _loadBill,
              )
            : _bill == null
                ? const SizedBox.shrink()
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final bill = _bill!;
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM dd, yyyy');

    return RefreshIndicator(
      onRefresh: _loadBill,
      child: ListView(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Status Card
          _StatusCard(bill: bill),
          
          SizedBox(height: 16.h),
          
          // Amount Card
          _AmountCard(
            totalAmount: bill.totalAmount,
            minimumDue: bill.minimumDue,
            currencyFormat: currencyFormat,
            isPaid: bill.isPaid,
          ),
          
          SizedBox(height: 16.h),
          
          // Dates Card
          _DatesCard(
            statementDate: bill.statementDate,
            dueDate: bill.dueDate,
            paidConfirmedAt: bill.paidConfirmedAt,
            dateFormat: dateFormat,
          ),
          
          SizedBox(height: 16.h),
          
          // Card Info Card
          _CardInfoCard(bill: bill),
          
          SizedBox(height: 16.h),
          
          // Extraction Info
          if (bill.requiresReview || bill.confidenceScore < 0.8)
            _ExtractionWarning(
              confidenceScore: bill.confidenceScore,
              requiresReview: bill.requiresReview,
            ),
          
          SizedBox(height: 24.h),
          
          // Action Buttons
          if (!bill.isPaid) ...[
            AppButton(
              text: 'Mark as Paid',
              onPressed: _showConfirmPaymentDialog,
              isLoading: _isConfirming,
              icon: Icons.check_circle_outline,
            ),
            SizedBox(height: 12.h),
            AppButton(
              text: 'Pay Now',
              onPressed: () {
                // TODO: Navigate to payment
              },
              type: AppButtonType.secondary,
              icon: Icons.payment,
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Confirmed',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                        if (bill.paidConfirmedAt != null)
                          Text(
                            'Confirmed on ${dateFormat.format(bill.paidConfirmedAt!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final BillDetail bill;

  const _StatusCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (bill.isPaid) {
      statusColor = AppColors.success;
      statusText = 'Paid';
      statusIcon = Icons.check_circle;
    } else if (bill.isOverdue) {
      statusColor = AppColors.error;
      statusText = '${-bill.daysUntilDue} days overdue';
      statusIcon = Icons.warning;
    } else if (bill.daysUntilDue <= 3) {
      statusColor = AppColors.warning;
      statusText = bill.daysUntilDue == 0
          ? 'Due today'
          : 'Due in ${bill.daysUntilDue} days';
      statusIcon = Icons.access_time;
    } else {
      statusColor = AppColors.primary;
      statusText = 'Due in ${bill.daysUntilDue} days';
      statusIcon = Icons.schedule;
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 28.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  final double totalAmount;
  final double? minimumDue;
  final NumberFormat currencyFormat;
  final bool isPaid;

  const _AmountCard({
    required this.totalAmount,
    this.minimumDue,
    required this.currencyFormat,
    required this.isPaid,
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
          Text(
            'Amount Due',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            currencyFormat.format(totalAmount),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPaid ? AppColors.success : null,
              decoration: isPaid ? TextDecoration.lineThrough : null,
            ),
          ),
          if (minimumDue != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16.w,
                  color: AppColors.lightTextSecondary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Minimum due: ${currencyFormat.format(minimumDue)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  final DateTime statementDate;
  final DateTime dueDate;
  final DateTime? paidConfirmedAt;
  final DateFormat dateFormat;

  const _DatesCard({
    required this.statementDate,
    required this.dueDate,
    this.paidConfirmedAt,
    required this.dateFormat,
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
        children: [
          _DateRow(
            label: 'Statement Date',
            date: dateFormat.format(statementDate),
            icon: Icons.receipt_long,
          ),
          Divider(height: 24.h),
          _DateRow(
            label: 'Payment Due Date',
            date: dateFormat.format(dueDate),
            icon: Icons.event,
            isImportant: true,
          ),
          if (paidConfirmedAt != null) ...[
            Divider(height: 24.h),
            _DateRow(
              label: 'Paid On',
              date: dateFormat.format(paidConfirmedAt!),
              icon: Icons.check_circle,
              iconColor: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String date;
  final IconData icon;
  final bool isImportant;
  final Color? iconColor;

  const _DateRow({
    required this.label,
    required this.date,
    required this.icon,
    this.isImportant = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20.w,
          color: iconColor ?? (isImportant ? AppColors.primary : AppColors.lightTextSecondary),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
        ),
        Text(
          date,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isImportant ? FontWeight.w600 : null,
            color: isImportant ? AppColors.primary : null,
          ),
        ),
      ],
    );
  }
}

class _CardInfoCard extends StatelessWidget {
  final BillDetail bill;

  const _CardInfoCard({required this.bill});

  Color _getBankColor() {
    switch (bill.bankName.toLowerCase()) {
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
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: _getBankColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Center(
              child: Text(
                bill.bankName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _getBankColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.cardName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${bill.bankName} •••• ${bill.lastFourDigits}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractionWarning extends StatelessWidget {
  final double confidenceScore;
  final bool requiresReview;

  const _ExtractionWarning({
    required this.confidenceScore,
    required this.requiresReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Text(
                'Review Recommended',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'This bill was automatically extracted with ${(confidenceScore * 100).toInt()}% confidence. Please verify the details are correct.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          if (requiresReview) ...[
            SizedBox(height: 12.h),
            TextButton.icon(
              onPressed: () {
                // TODO: Navigate to edit screen
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Details'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: AppColors.error,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

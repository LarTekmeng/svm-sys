import 'package:flutter/material.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';

class DocumentHeader extends StatelessWidget {
  final String uploaderName;
  final String uploaderDepartmentName;
  final DateTime postedAt;
  final bool canAct;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const DocumentHeader({
    super.key,
    required this.uploaderName,
    required this.uploaderDepartmentName,
    required this.postedAt,
    required this.canAct,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: $uploaderName (Dp: $uploaderDepartmentName)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white)),
            const SizedBox(height: 4),
            Text('Posted: ${_fmt(postedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.white)),
            if (canAct) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: AppColors.white
                      ),
                      icon: const Icon(Icons.check),
                      onPressed: onApprove,
                      label: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.close),
                      onPressed: onReject,
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

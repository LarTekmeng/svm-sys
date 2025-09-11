import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';

class DocumentSteps extends StatelessWidget {
  final String forwardMode; // 'Direct' | 'Step by Step'
  final int flowsCount;
  final List<DocumentStep> steps;

  const DocumentSteps({
    super.key,
    required this.forwardMode,
    required this.flowsCount,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    if (forwardMode != 'Step by Step') return const SizedBox.shrink();

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sequence ($flowsCount steps)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: steps.map((s) => _StepChip(s)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final DocumentStep s;
  const _StepChip(this.s);

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (s.status) {
      case 'APPROVED': bg = Colors.green.withOpacity(.15); break;
      case 'REJECTED': bg = Colors.red.withOpacity(.15); break;
      default: bg = Colors.orange.withOpacity(.15);
    }
    return Chip(
      backgroundColor: bg,
      label: Text('#${s.sequence} • ${s.status} • ${s.employeeName}'),
    );
  }
}

import 'package:flutter/material.dart';

class DocumentItem extends StatelessWidget {
  final int documentId;
  final String? status;   // nullable
  final String title;
  final String desc;
  final bool isReadOnly;  // hide chip when true
  final VoidCallback? onTap; // NEW: let the parent decide navigation

  const DocumentItem({
    super.key,
    required this.documentId,
    required this.status,
    required this.title,
    required this.desc,
    this.isReadOnly = false,
    this.onTap, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final s = (status ?? '').trim();
    final sUpper = s.toUpperCase();
    final showStatus = !isReadOnly && s.isNotEmpty;

    Color chipColor(String su) {
      switch (su) {
        case 'COMPLETED': return Colors.green;
        case 'REJECTED':  return Colors.red;
        case 'PENDING':   return Colors.grey;
        default:          return Colors.grey;
      }
    }

    return InkWell(
      onTap: onTap, // NEW
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                )),
            Row(
              children: [
                Expanded(
                  child: Text(
                    desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                if (showStatus) const SizedBox(width: 10),
                if (showStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: chipColor(sUpper),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sUpper,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const Divider(color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:online_doc_savimex/feature/screen/document/view_document.dart';

class DocumentItem extends StatelessWidget {
  final int documentId;
  final String? status;   // nullable
  final String title;
  final String desc;
  final bool isReadOnly;  // hide chip when true

  const DocumentItem({
    super.key,
    required this.documentId,
    required this.status,
    required this.title,
    required this.desc,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // normalize once
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
      onTap: () {
        // If your widget in view_document.dart is named ViewDocument,
        // change DocumentScreen(...) to ViewDocument(...).
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentScreen(documentId: documentId)),
        );
      },
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
                      sUpper, // display normalized status
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

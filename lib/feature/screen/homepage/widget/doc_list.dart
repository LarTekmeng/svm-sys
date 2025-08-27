import 'package:flutter/material.dart';
import 'package:online_doc_savimex/feature/screen/document/view_document.dart';

class DocumentItem extends StatelessWidget {
  final int documentId;        // <-- add this
  final String status;
  final String title;
  final String desc;

  const DocumentItem({
    super.key,
    required this.documentId,  // <-- require it
    required this.status,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentScreen(documentId: documentId), // <-- use it
          ),
        );
      },
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status == "COMPLETED"
                        ? Colors.green
                        : status == "REJECTED"
                        ? Colors.red
                        : status == "PENDING"
                        ? Colors.grey
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
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

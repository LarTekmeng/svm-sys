import 'package:flutter/material.dart';
import 'package:online_doc_savimex/feature/screen/document/view_document.dart';

class DocumentItem extends StatelessWidget {
  final String status;
  final String title;
  final String desc;

  const DocumentItem({
    super.key,
    required this.status,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentScreen()));},
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                    color: status == "Approved" ? Colors.green : status == "Rejected" ? Colors.red : status == "In progress" ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
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
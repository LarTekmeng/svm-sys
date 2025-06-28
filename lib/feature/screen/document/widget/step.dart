import 'package:flutter/material.dart';

class TimelineStep extends StatelessWidget {
  final int step;
  final String name;
  final String status;
  final String date;

  const TimelineStep({
    super.key,
    required this.step,
    required this.name,
    required this.status,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Text('$step', style: const TextStyle(color: Colors.white)),
            ),
            if (step < 3)
              Container(width: 2, height: 20, color: Colors.grey.shade400),
          ],
        ),
        const SizedBox(width: 12),
        // Align text vertically with the center of the circle
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12), // Adjust for vertical alignment
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: "$name → ",style: TextStyle(color: Colors.white)),
                  TextSpan(
                    text: "$status",
                    style: TextStyle(
                      color: status == "Approved"
                          ? Colors.blue
                          : status == "Checked"
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: " - $date", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    );

  }
}
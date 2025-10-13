import 'package:flutter/material.dart';

Widget mainButton(VoidCallback onTap, String text, Color color) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
    ),
    onPressed: onTap,
    child: Text(text, style: TextStyle(fontSize: 18, color: Colors.white)),
  );
}

Widget btnListAction(VoidCallback btnTrash, VoidCallback btnArchive){
  return Container(
    height: 50,
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          //Trash
          TextButton(
            onPressed: btnTrash,
            child: Text(
            'Trash',
              style: TextStyle(color: Colors.yellow),
            ),
          ),
          //Archive
          TextButton(
            onPressed: btnArchive,
            child: Text(
              'Archive',
              style: TextStyle(color: Colors.yellow),
            ),
          ),
        ],
      ),
    ),
  );
}

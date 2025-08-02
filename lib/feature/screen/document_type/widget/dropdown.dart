import 'package:flutter/material.dart';

Widget buildDropdownRow() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: dropdownField('Department', [
          'all',
          'HR',
          'Accounting',
          'Finance',
          'Sale',
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: dropdownField('Employee', ['all','Pheak', 'Heng', 'Rith', 'Krissna']),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: dropdownField('Action', [
          'Approval', /* this equal checked at then push to Approve & Signature */
          'Signature', /* normally use when top position in the company like CEO or Head of Department*/
        ]),
      ),
    ],
  );
}

Widget dropdownField(String label, List<String> items) {
  return DropdownButtonFormField<String>(
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    isExpanded: true, // ✅ Important: makes dropdown take full width
    items: items.map((e) {
      return DropdownMenuItem(
        value: e,
        child: Text(
          e,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontSize: 13),
        ),
      );
    }).toList(),
    onChanged: (value) {},
  );
}



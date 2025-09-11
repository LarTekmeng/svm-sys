// lib/feature/screen/Doc_type/dropdown.dart
import 'package:flutter/material.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';

/// A parameterized dropdown block for selecting department, then employee & action.
/// - deptItems & empItems are lists of **IDs** (e.g. ['all','3','5',…])
/// - deptNameMap & empNameMap map those IDs to display names
Widget buildFlowRow({
  required String? selectedDept,
  required String? selectedEmp,
  required String? selectedAction,

  // ID lists
  required List<String> deptItems,
  required List<String> empItems,
  required List<String> actionItems,

  // ID → display name
  required Map<String, String> deptNameMap,
  required Map<String, String> empNameMap,

  // callbacks
  required ValueChanged<String?> onDeptChanged,
  required ValueChanged<String?> onEmpChanged,
  required ValueChanged<String?> onActionChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ─── Department (full width) ──────────────────────────────────────────
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          fillColor: AppColors.white,
          filled: true,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.black38, width: 1)
          ),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.black38, width: 1)
          ),
          isDense: true,
        ),
        value: selectedDept,
        hint: Text('Department'),
        items: deptItems.map((deptId) {
          final label = deptId == 'all'
              ? 'All Departments'
              : (deptNameMap[deptId] ?? deptId);
          return DropdownMenuItem(
            value: deptId,
            child: Text(label),
          );
        }).toList(),
        onChanged: onDeptChanged,
      ),

      const SizedBox(height: 8),

      // ─── Employee & Action (side by side) ─────────────────────────────────
      Row(
        children: [
          // Employee
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.black38, width: 1)
                ),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.black38, width: 1)
                ),
                isDense: true,
              ),
              value: selectedEmp,
              hint: const Text('Employee'),
              items: empItems.map((empId) {
                final label = empId == 'all'
                    ? 'All Employees'
                    : (empNameMap[empId] ?? empId);
                return DropdownMenuItem(
                  value: empId,
                  child: Text(label),
                );
              }).toList(),
              onChanged: onEmpChanged,
            ),
          ),

          const SizedBox(width: 8),

          // Action
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.black38, width: 1)
                ),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.black38, width: 1)
                ),
                isDense: true,
              ),
              value: selectedAction,
              hint: const Text('Select Action'),
              items: actionItems.map((action) {
                return DropdownMenuItem(
                  value: action,
                  child: Text(action),
                );
              }).toList(),
              onChanged: onActionChanged,
            ),
          ),
        ],
      ),
    ],
  );
}

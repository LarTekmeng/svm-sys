import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';

class SetDocumentTypeScreen extends StatefulWidget {
  final int documentTypeId;
  const SetDocumentTypeScreen({super.key, required this.documentTypeId});

  @override
  State<SetDocumentTypeScreen> createState() => _SetDocumentTypeScreenState();
}

class _SetDocumentTypeScreenState extends State<SetDocumentTypeScreen> {
  late final DoctypeRepository _repo;

  String selectedAction = 'Read-Only';
  String selectedForwardMode = '';

  bool isDirectExpanded = false;
  bool isStepExpanded = false;

  List<String> deptItems = ['all'];
  List<String> allEmpItems = ['all'];
  Map<String, List<String>> empMap = {};
  Map<String, String> deptNameMap = {};
  Map<String, String> empNameMap = {};
  final actionItems = const ['APPROVAL', 'SIGNATURE'];

  List<String?> selectedDepts = [];
  List<String?> selectedEmps = [];
  List<String?> selectedActions = [];

  @override
  void initState() {
    super.initState();
    _repo = context.read<DoctypeRepository>();
    _loadMetadata().then((_) => _prefillFromServer());
  }

  Future<void> _loadMetadata() async {
    final depts = await _repo.getDepartment();
    final emps = await _repo.getEmployee();

    final deptIds = ['all', ...depts.map((d) => d.id.toString())];
    final dMap = {for (var d in depts) d.id.toString(): d.name};

    final allEmps = ['all', ...emps.map((e) => e.id.toString())];
    final eMap = {for (var e in emps) e.id.toString(): e.employeeName};

    final grouped = <String, List<String>>{};
    for (var d in depts) {
      final key = d.id.toString();
      grouped[key] = [
        'all',
        ...emps
            .where((e) => e.departmentID.toString() == key)
            .map((e) => e.id.toString()),
      ];
    }

    setState(() {
      deptItems = deptIds;
      deptNameMap = dMap;
      allEmpItems = allEmps;
      empNameMap = eMap;
      empMap = grouped;

      // Start with a single row
      selectedDepts = List.filled(1, null, growable: true);
      selectedEmps = List.filled(1, null, growable: true);
      selectedActions = List.filled(1, null, growable: true);
    });
  }

  void _ensureAtLeastRows(int n) {
    // Expand lists to at least n, preserving existing values
    while (selectedDepts.length < n) selectedDepts.add(null);
    while (selectedEmps.length < n) selectedEmps.add(null);
    while (selectedActions.length < n) selectedActions.add(null);
  }

  void _trimToRows(int n) {
    // Trim lists to exactly n, preserving first n values
    if (selectedDepts.length > n) selectedDepts = selectedDepts.sublist(0, n);
    if (selectedEmps.length > n) selectedEmps = selectedEmps.sublist(0, n);
    if (selectedActions.length > n) {
      selectedActions = selectedActions.sublist(0, n);
    }
  }

  void _addRow() {
    setState(() {
      selectedDepts.add(null);
      selectedEmps.add(null);
      selectedActions.add(null);
    });
  }

  void _removeRow() {
    if (selectedDepts.length > 1) {
      setState(() {
        selectedDepts.removeLast();
        selectedEmps.removeLast();
        selectedActions.removeLast();
      });
    }
  }

  Future<void> _onConfirm() async {
    // Build flows from current UI state.
    final flows = <Map<String, dynamic>>[];
    for (var i = 0; i < selectedDepts.length; i++) {
      final step =
          (selectedAction == 'Read-Only')
              ? 'READ-ONLY'
              : (selectedActions[i] ?? 'APPROVAL');
      flows.add({
        'sequence': i + 1,
        'department_id': selectedDepts[i] ?? 'all',
        'employee_id': selectedEmps[i] ?? 'all',
        'step_action': step,
      });
    }

    final _fm = selectedAction == 'Read-Only' ? 'Direct' : selectedForwardMode;

    await _repo.setDocTypeFlow(
      widget.documentTypeId,
      selectedAction, // 'Read-Only' or 'Ask for Permission'
      _fm, // 'Direct' or 'Step by Step'
      flows, // preserved/edited flows
    );

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _prefillFromServer() async {
    try {
      final data = await _repo.fetchDocTypeFlow(widget.documentTypeId);
      final settings = (data['settings'] ?? {}) as Map<String, dynamic>;
      final serverFlows = (data['flows'] ?? []) as List;

      final serverAction = (settings['action'] ?? 'Read-Only').toString();
      final serverMode = (settings['forward_mode'] ?? '').toString();

      // Always set action first
      selectedAction = serverAction;

      if (serverAction == 'Read-Only') {
        // Runtime uses Direct, but we still show (and keep) saved flows
        setState(() {
          isDirectExpanded = true;
          isStepExpanded = false;
          selectedForwardMode = 'Direct';

          final count = serverFlows.isEmpty ? 1 : serverFlows.length;
          selectedDepts = List<String?>.filled(count, null, growable: true);
          selectedEmps = List<String?>.filled(count, null, growable: true);
          selectedActions = List<String?>.filled(count, null, growable: true);

          for (var i = 0; i < serverFlows.length; i++) {
            final f = serverFlows[i] as Map<String, dynamic>;
            selectedDepts[i] = (f['department_id']?.toString()) ?? 'all';
            selectedEmps[i] = (f['employee_id']?.toString()) ?? 'all';
            selectedActions[i] = (f['step_action']?.toString()) ?? 'READ-ONLY';
          }
        });
        return;
      }

      if (serverMode == 'Direct') {
        setState(() {
          isDirectExpanded = true;
          isStepExpanded = false;
          selectedForwardMode = 'Direct';

          selectedDepts = List<String?>.filled(1, null, growable: true);
          selectedEmps = List<String?>.filled(1, null, growable: true);
          selectedActions = List<String?>.filled(1, null, growable: true);

          if (serverFlows.isNotEmpty) {
            final f = serverFlows.first as Map<String, dynamic>;
            selectedDepts[0] = (f['department_id']?.toString()) ?? 'all';
            selectedEmps[0] = (f['employee_id']?.toString()) ?? 'all';
            selectedActions[0] = (f['step_action']?.toString()) ?? 'APPROVAL';
          }
        });
      } else if (serverMode == 'Step by Step') {
        setState(() {
          isDirectExpanded = false;
          isStepExpanded = true;
          selectedForwardMode = 'Step by Step';

          final count = serverFlows.isEmpty ? 2 : serverFlows.length;
          selectedDepts = List<String?>.filled(count, null, growable: true);
          selectedEmps = List<String?>.filled(count, null, growable: true);
          selectedActions = List<String?>.filled(count, null, growable: true);

          for (var i = 0; i < serverFlows.length; i++) {
            final f = serverFlows[i] as Map<String, dynamic>;
            selectedDepts[i] = (f['department_id']?.toString()) ?? 'all';
            selectedEmps[i] = (f['employee_id']?.toString()) ?? 'all';
            selectedActions[i] = (f['step_action']?.toString()) ?? 'APPROVAL';
          }
        });
      } else {
        // Unknown/empty mode — leave defaults
        setState(() {
          isDirectExpanded = true;
          selectedForwardMode = 'Direct';
        });
      }
    } catch (e) {
      debugPrint('Prefill failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeText = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppColors.white,
      fontWeight: FontWeight.w500,
    );
    final mediumText = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: AppColors.white);

    final stepDisabled = selectedAction == 'Read-Only';
    final readOnly = selectedAction == 'Read-Only';
    final rowActionItems =
        readOnly ? const ['READ-ONLY'] : const ['APPROVAL', 'SIGNATURE'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Set Document Type Flow', style: largeText),
        foregroundColor: AppColors.white,
        backgroundColor: AppColors.background,
      ),
      body:
          (deptItems.length == 1)
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Action:', style: mediumText),
                    // RadioListTile<String>(
                    //   title: Text('Read-Only', style: mediumText),
                    //   value: 'Read-Only',
                    //   groupValue: selectedAction,
                    //   onChanged:
                    //       (v) => setState(() {
                    //         selectedAction = v!;
                    //         isStepExpanded = false;
                    //         isDirectExpanded = true;
                    //         selectedForwardMode = 'Direct';
                    //         if (selectedDepts.isEmpty) _ensureAtLeastRows(1);
                    //         _trimToRows(1);
                    //         if (selectedActions.isEmpty) _ensureAtLeastRows(1);
                    //         for (var i = 0; i < selectedActions.length; i++) {
                    //           selectedActions[i] ??= 'READ-ONLY';
                    //         }
                    //       }),
                    // ),
                    // RadioListTile<String>(
                    //   title: Text('Ask for Permission', style: mediumText),
                    //   value: 'Ask for Permission',
                    //   groupValue: selectedAction,
                    //   onChanged:
                    //       (v) => setState(() {
                    //         selectedAction = v!;
                    //         for (var i = 0; i < selectedActions.length; i++) {
                    //           if (selectedActions[i] == 'READ-ONLY') {
                    //             selectedActions[i] = null;
                    //           }
                    //         }
                    //       }),
                    // ),
                    RadioGroup<String>(
                      groupValue: selectedAction,
                      onChanged:
                          (String? v) => setState(() {
                            selectedAction = v!;

                            if (v == 'Read-Only') {
                              isStepExpanded = false;
                              isDirectExpanded = true;
                              selectedForwardMode = 'Direct';

                              if (selectedDepts.isEmpty) _ensureAtLeastRows(1);
                              _trimToRows(1);

                              if (selectedActions.isEmpty)
                                _ensureAtLeastRows(1);
                              for (var i = 0; i < selectedActions.length; i++) {
                                selectedActions[i] ??= 'READ-ONLY';
                              }
                            } else if (v == 'Ask for Permission') {
                              for (var i = 0; i < selectedActions.length; i++) {
                                if (selectedActions[i] == 'READ-ONLY') {
                                  selectedActions[i] = null;
                                }
                              }
                            }
                          }),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioListTile<String>(
                            value: 'Read-Only',
                            title: Text('Read-Only', style: mediumText),
                            // Note: no groupValue/onChanged here
                          ),
                          RadioListTile<String>(
                            value: 'Ask for Permission',
                            title: Text(
                              'Ask for Permission',
                              style: mediumText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Forward Mode:', style: mediumText),
                    Wrap(
                      spacing: 16,
                      children: [
                        ChoiceChip(
                          label: const Text('Direct'),
                          selected: isDirectExpanded,
                          onSelected:
                              (on) => setState(() {
                                isDirectExpanded = on;
                                isStepExpanded = false;
                                selectedForwardMode = on ? 'Direct' : '';
                                // Keep first row’s values; trim to 1 row.
                                if (selectedDepts.isEmpty)
                                  _ensureAtLeastRows(1);
                                _trimToRows(1);
                              }),
                        ),
                        ChoiceChip(
                          label: const Text('Step by Step'),
                          selected: isStepExpanded,
                          onSelected:
                              stepDisabled
                                  ? null
                                  : (on) => setState(() {
                                    isStepExpanded = on;
                                    isDirectExpanded = false;
                                    selectedForwardMode =
                                        on ? 'Step by Step' : '';
                                    // Keep existing values. Ensure min 2 rows.
                                    _ensureAtLeastRows(2);
                                  }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isDirectExpanded || isStepExpanded) ...[
                      for (var i = 0; i < selectedDepts.length; i++) ...[
                        buildFlowRow(
                          selectedDept: selectedDepts[i],
                          selectedEmp: selectedEmps[i],
                          selectedAction: selectedActions[i],
                          deptItems: deptItems,
                          empItems:
                              (selectedDepts[i] != null &&
                                      selectedDepts[i] != 'all')
                                  ? (empMap[selectedDepts[i]] ?? allEmpItems)
                                  : allEmpItems,
                          actionItems: rowActionItems,
                          onDeptChanged:
                              (v) => setState(() {
                                selectedDepts[i] = v;
                                selectedEmps[i] =
                                    null; // reset employee on dept change
                              }),
                          onEmpChanged:
                              (v) => setState(() => selectedEmps[i] = v),
                          onActionChanged:
                              (v) => setState(() => selectedActions[i] = v),
                          deptNameMap: deptNameMap,
                          empNameMap: empNameMap,
                        ),
                        if (selectedDepts.length > 1) const Divider(),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (selectedDepts.length > 1)
                            TextButton(
                              onPressed: _removeRow,
                              child: const Text(
                                'Undo',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          TextButton(
                            onPressed: _addRow,
                            child: const Text(
                              'Add more',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: mainButton(_onConfirm, 'Confirm', Colors.green),
      ),
    );
  }
}

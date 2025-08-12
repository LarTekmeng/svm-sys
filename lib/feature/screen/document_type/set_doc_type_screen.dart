import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/repositories/doctype_repo.dart';

class SetDocumentTypeScreen extends StatefulWidget {
  final int documentTypeId;
  const SetDocumentTypeScreen({super.key, required this.documentTypeId});

  @override
  State<SetDocumentTypeScreen> createState() => _SetDocumentTypeScreenState();
}

class _SetDocumentTypeScreenState extends State<SetDocumentTypeScreen> {
  final _repo = DoctypeRepository();

  String selectedAction = 'Read-Only';
  String selectedForwardMode = '';

  bool isDirectExpanded = false;
  bool isStepExpanded = false;

  List<String> deptItems = ['all'];
  List<String> allEmpItems = ['all'];
  Map<String, List<String>> empMap = {};
  Map<String, String> deptNameMap = {};
  Map<String, String> empNameMap = {};
  final actionItems = ['APPROVAL', 'SIGNATURE'];

  List<String?> selectedDepts = [];
  List<String?> selectedEmps = [];
  List<String?> selectedActions = [];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final depts = await _repo.getDepartment();
    final emps = await _repo.getEmployee();

    // 1) dept IDs & name map
    final deptIds = ['all', ...depts.map((d) => d.id.toString())];
    final dMap = {for (var d in depts) d.id.toString(): d.name};

    // 2) employee flat list & name map
    final allEmps = ['all', ...emps.map((e) => e.id.toString())];
    final eMap = {for (var e in emps) e.id.toString(): e.employeeName};

    // 3) build empMap keyed by deptID
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
      selectedDepts = List.filled(1, null, growable: true);
      selectedEmps = List.filled(1, null, growable: true);
      selectedActions = List.filled(1, null, growable: true);
    });
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
    final flows = <Map<String, dynamic>>[];
    for (var i = 0; i < selectedDepts.length; i++) {
      flows.add({
        'sequence': i + 1,
        'department_id': selectedDepts[i] ?? 'all',
        'employee_id': selectedEmps[i] ?? 'all',
        'step_action': selectedActions[i] ?? 'APPROVAL',
      });
    }
    await _repo.setDocTypeFlow(
      widget.documentTypeId,
      selectedAction,
      selectedForwardMode,
      flows,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final stepDisabled = selectedAction == 'Read-Only';

    return Scaffold(
      appBar: AppBar(title: const Text('Set Document Type Flow')),
      body:
          deptItems.length == 1
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Action:'),
                    RadioListTile<String>(
                      title: const Text('Read-Only'),
                      value: 'Read-Only',
                      groupValue: selectedAction,
                      onChanged:
                          (v) => setState(() {
                            selectedAction = v!;
                            if (v == 'Read-Only') {
                              isStepExpanded = false;
                              isDirectExpanded = false;
                              selectedForwardMode = '';
                            }
                          }),
                    ),
                    RadioListTile<String>(
                      title: const Text('Ask for Permission'),
                      value: 'Ask for Permission',
                      groupValue: selectedAction,
                      onChanged: (v) => setState(() => selectedAction = v!),
                    ),
                    const SizedBox(height: 16),
                    const Text('Forward Mode:'),
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
                                selectedDepts = List.filled(1, null, growable: true);
                                selectedEmps = List.filled(1, null, growable: true);
                                selectedActions = List.filled(1, null, growable: true);
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
                                    selectedDepts = List.filled(2, null, growable: true);
                                    selectedEmps = List.filled(2, null, growable: true);
                                    selectedActions = List.filled(2, null, growable: true);
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
                                  ? empMap[selectedDepts[i]]!
                                  : allEmpItems,
                          actionItems: actionItems,
                          onDeptChanged:
                              (v) => setState(() {
                                selectedDepts[i] = v;
                                // reset employee when dept changes
                                selectedEmps[i] = null;
                              }),
                          onEmpChanged:
                              (v) => setState(() => selectedEmps[i] = v),
                          onActionChanged:
                              (v) => setState(() => selectedActions[i] = v),
                          deptNameMap: deptNameMap,
                          empNameMap: empNameMap,
                        ),
                        if(selectedDepts.length > 1)
                          Divider(),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (selectedDepts.length > 1)
                            TextButton(
                              onPressed: _removeRow,
                              child: const Text('Undo'),
                            ),
                          TextButton(
                            onPressed: _addRow,
                            child: const Text('Add more'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _onConfirm,
          child: const Text('Confirm'),
        ),
      ),
    );
  }
}

import 'package:online_doc_savimex/app_import.dart';

class SetDocumentTypeScreen extends StatefulWidget {
  const SetDocumentTypeScreen({super.key});

  @override
  State<SetDocumentTypeScreen> createState() => _SetDocumentTypeScreenState();
}

class _SetDocumentTypeScreenState extends State<SetDocumentTypeScreen> {
  String selectedAction = 'Read-Only';
  String selectedForwardMode = '';

  bool isDirectExpanded = false;
  bool isStepExpanded = false;

  List<int> directList = [0]; // default: 1 dropdown
  List<int> stepList = [0, 1]; // default: 2 dropdowns

  void addDirect() => setState(() => directList.add(directList.length));
  void undoDirect() {
    if (directList.length > 1) {
      setState(() => directList.removeLast());
    }
  }

  void addStep() => setState(() => stepList.add(stepList.length));
  void undoStep() {
    if (stepList.length > 2) {
      setState(() => stepList.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(backgroundColor: Colors.transparent,),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Document Type:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Accounting',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text('Document type action:'),
              RadioListTile(
                title: const Text('Read Only'),
                value: 'Read-Only',
                groupValue: selectedAction,
                onChanged: (val) => setState(() => selectedAction = val!),
              ),
              RadioListTile(
                title: const Text('Ask for Permission'),
                value: 'Ask for Permission',
                groupValue: selectedAction,
                onChanged: (val) => setState(() => selectedAction = val!),
              ),
              const SizedBox(height: 10),
              const Text('Forward to:'),
              IgnorePointer(
                ignoring: isStepExpanded, // disable if Step by Step is active
                child: Opacity(
                  opacity: isStepExpanded ? 0.4 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isDirectExpanded = !isDirectExpanded;
                            isStepExpanded = false; // close the other section
                            selectedForwardMode =
                                isDirectExpanded ? 'Direct' : '';
                            directList = [0]; // reset to default
                          });
                        },
                        child: Text(
                          '${isDirectExpanded ? '➖' : '➕'} Direct',
                          style: TextStyle(
                            color: isStepExpanded ? Colors.grey : Colors.blue,
                            fontWeight:
                                isDirectExpanded
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isDirectExpanded) ...[
                        for (var i in directList) ...[
                          buildDropdownRow(),
                          const SizedBox(height: 10),
                        ],
                        if (directList.length > 1)
                          TextButton(
                            onPressed: undoDirect,
                            child: const Text('↩️ Undo'),
                          ),
                        TextButton(
                          onPressed: addDirect,
                          child: const Text('➕ add more'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // Step by Step Section Toggle
              IgnorePointer(
                ignoring: isDirectExpanded, // disable if Direct is active
                child: Opacity(
                  opacity: isDirectExpanded ? 0.4 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isStepExpanded = !isStepExpanded;
                            isDirectExpanded = false; // close the other section
                            selectedForwardMode =
                                isStepExpanded ? 'Step by Step' : '';
                            stepList = [0, 1]; // reset to default
                          });
                        },
                        child: Text(
                          '${isStepExpanded ? '➖' : '➕'} Step by Step',
                          style: TextStyle(
                            color: isDirectExpanded ? Colors.grey : Colors.blue,
                            fontWeight:
                                isStepExpanded
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isStepExpanded) ...[
                        for (var i in stepList) ...[
                          buildDropdownRow(),
                          const SizedBox(height: 10),
                        ],
                        if (stepList.length > 2)
                          TextButton(
                            onPressed: undoStep,
                            child: const Text('↩️ Undo'),
                          ),
                        TextButton(
                          onPressed: addStep,
                          child: const Text('➕ add more'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Direct Section Toggle
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20,0,20,50),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Confirm', style: TextStyle(color: Colors.white),),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel', style: TextStyle(color: Colors.white),),
            ),
          ],
        ),
      ),
    );
  }
}
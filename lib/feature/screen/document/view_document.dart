import 'package:flutter/material.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/first_section.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/step.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DocumentScreen(),
  ));
}

class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: (){Navigator.pop(context);}, ),
        backgroundColor: Color.fromRGBO(0, 105, 133, 1),
        elevation: 0,
      ),
      backgroundColor: Color.fromRGBO(0, 105, 133, 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fromEmployee(),
            const Divider(),
            const TimelineStep(
              step: 1,
              name: "Pheak (HR)",
              status: "Checked",
              date: "1 January 2031",
            ),
            const TimelineStep(
              step: 2,
              name: "Rith (Accounting)",
              status: "Checked",
              date: "2 January 2031",
            ),
            const TimelineStep(
              step: 3,
              name: "Boss (CEO)",
              status: "Approved",
              date: "5 January 2031",
            ),
            const Divider(),
            const SizedBox(height: 10),
            const Text("Document Title",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text("This is the main description of this document...",style: TextStyle(color: Colors.white),),
            const SizedBox(height: 10),
            /*this is original file that upload by the poster*/
            const DocumentBox(from: "tekmeng (IT)"),
            /*this file is added during other employee check*/
            const DocumentBox(from: "Pheak (HR)"),
            /*this file is added during other employee check*/
            const DocumentBox(from: "Rith (Account)"),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            /* this Icon is where other employee beside employee that posted the current document to add more file into document */
            IconButton(onPressed: (){}, icon: Icon(Icons.attachment_outlined)),
            /*this Icon is chat room that connect with current poster and current viewer*/
            IconButton(onPressed: (){}, icon: Icon(Icons.chat)),
          ],
        ),
      ),
    );
  }
}

class DocumentBox extends StatelessWidget {
  final String? from;
  const DocumentBox({super.key, this.from});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (from != null) Text("From: $from"),
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 16),
          height: 150,
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: -0.3,
            child: const Text(
              "This is Document",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Text('This is description')
      ],
    );
  }
}

import 'dart:io';

export 'package:flutter/material.dart';
export 'package:flutter_bloc/flutter_bloc.dart';
export 'package:image_picker/image_picker.dart';

/* persist user login (Remember Me) */
export 'package:flutter_secure_storage/flutter_secure_storage.dart';
/* ===== */

/*Login BLOC*/
export 'package:online_doc_savimex/feature/bloc/login_bloc/bloc.dart';
export 'package:online_doc_savimex/feature/bloc/login_bloc/event.dart';
export 'package:online_doc_savimex/feature/bloc/login_bloc/state.dart';
/* ===== */

/*Register BLOC*/
export 'package:online_doc_savimex/feature/bloc/register_bloc/bloc.dart';
export 'package:online_doc_savimex/feature/bloc/register_bloc/event.dart';
export 'package:online_doc_savimex/feature/bloc/register_bloc/state.dart';
/* ===== */

/*Screen route*/
export 'package:online_doc_savimex/feature/screen/register/register.dart';
export 'package:online_doc_savimex/feature/screen/homepage/homescreen.dart';
export 'package:online_doc_savimex/feature/screen/Login/login_screen.dart';
export 'package:online_doc_savimex/feature/screen/document_type/set_doc_type_screen.dart';
export 'package:online_doc_savimex/feature/screen/document_type/create_doc_type_screen.dart';
export 'package:online_doc_savimex/feature/screen/document_type/doc_type_screen.dart';
export 'package:online_doc_savimex/feature/screen/upload/upload_screen.dart';

/* ===== */

/*Widget*/
export 'package:online_doc_savimex/feature/screen/document_type/widget/doc_type_card.dart';
export 'package:online_doc_savimex/feature/screen/document_type/widget/dropdown.dart';
export 'package:online_doc_savimex/feature/widget/search.dart';
export 'package:online_doc_savimex/feature/widget/button.dart';
export 'package:online_doc_savimex/feature/screen/Upload/widget/uploadBlock.dart';
export 'package:online_doc_savimex/feature/screen/homepage/widget/drawer_home_screen.dart';
export 'package:online_doc_savimex/feature/screen/homepage/widget/doc_list.dart';
/* ===== */

/*Repositories*/
export 'package:online_doc_savimex/feature/repositories/auth_repo.dart';
export 'package:online_doc_savimex/feature/repositories/employee_repo.dart';
export 'package:online_doc_savimex/feature/repositories/department_repo.dart';
/* ===== */

/*Models*/
export 'package:online_doc_savimex/feature/model/department.dart';
export 'package:online_doc_savimex/feature/model/document.dart';
export 'package:online_doc_savimex/feature/model/document_type.dart';
export 'package:online_doc_savimex/feature/model/employee.dart';
/* ===== */

/*Service*/
export 'package:online_doc_savimex/feature/service/doctype_service.dart';
export 'package:online_doc_savimex/feature/service/document_service.dart';
/* ===== */

String getLocalhost(){
  if(Platform.isAndroid){
    return 'http://10.0.2.2:3000';
  } else {
    return 'http://localhost:3000';
  }
}
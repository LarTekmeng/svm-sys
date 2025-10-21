import 'dart:io';

export 'package:flutter/material.dart';
export 'package:flutter_bloc/flutter_bloc.dart';
export 'package:image_picker/image_picker.dart';

/* persist user login (Remember Me) */
export 'package:flutter_secure_storage/flutter_secure_storage.dart';
/* ===== */

/*Login BLOC*/
export 'package:online_doc_savimex/feature/bloc/loginBLoC/login_bloc.dart';
export 'package:online_doc_savimex/feature/bloc/loginBLoC/login_event.dart';
export 'package:online_doc_savimex/feature/bloc/loginBLoC/login_state.dart';
/* ===== */

/*Register BLOC*/
export 'package:online_doc_savimex/feature/bloc/registerBLoC/register_bloc.dart';
export 'package:online_doc_savimex/feature/bloc/registerBLoC/register_event.dart';
export 'package:online_doc_savimex/feature/bloc/registerBLoC/register_state.dart';
/* ===== */

/*Home BLoC*/
export 'package:online_doc_savimex/feature/bloc/homeBLoC/home_bloc.dart';
export 'package:online_doc_savimex/feature/bloc/homeBLoC/home_state.dart';
export 'package:online_doc_savimex/feature/bloc/homeBLoC/home_event.dart';
/* ===== */

/*upload BLoC*/
export 'package:online_doc_savimex/feature/bloc/uploadBLoC/upload_bloc.dart';
export 'package:online_doc_savimex/feature/bloc/uploadBLoC/upload_event.dart';
export 'package:online_doc_savimex/feature/bloc/uploadBLoC/upload_state.dart';
/* ===== */

/*view BLoC*/
export 'package:online_doc_savimex/feature/bloc/viewBLoC/view_bloc.dart';
export 'package:online_doc_savimex/feature/bloc/viewBLoC/view_state.dart';
export 'package:online_doc_savimex/feature/bloc/viewBLoC/view_event.dart';
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
export 'package:online_doc_savimex/feature/repositories/doctype_repo.dart';
export 'package:online_doc_savimex/feature/repositories/document_repo.dart';
export 'package:online_doc_savimex/feature/repositories/home_repo.dart';
/* ===== */

/*Models*/
export 'package:online_doc_savimex/feature/model/department_mdl.dart';
export 'package:online_doc_savimex/feature/model/document_mdl.dart';
export 'package:online_doc_savimex/feature/model/document_type_mdl.dart';
export 'package:online_doc_savimex/feature/model/employee_mdl.dart';
/* ===== */


String getLocalhost(){
  if(Platform.isAndroid){
    return 'http://10.0.2.2:3000';
  } else {
    return 'http://localhost:3000';
  }
}
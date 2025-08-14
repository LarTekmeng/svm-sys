import 'package:flutter/material.dart';

Widget fromEmployee() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          /*Employee_name; Department and Create_date*/
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: tekmeng (Dp: IT)',style: TextStyle(color: Colors.white),),
              // Posted Date
              Text('Date: 29 May 2025',style: TextStyle(color: Colors.white),)],
          ),
        ],
      ),
      /*if viewer = poster this section is hidden and if viewer = receiver this section is visible in other to take action and appear only when flow = ask permission*/
      Row(
        children: [
          GestureDetector(
            onTap: (){
              print('Approved Document');
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green, // background color
              ),
              child: Center(
                child: Icon(
                  Icons.check,
                  color: Colors.white, // icon color
                ),
              ),
            ),
          ),
          SizedBox(width: 10,),
          GestureDetector(
            onTap: (){
              print('Rejected Document');
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red, // background color
              ),
              child: Center(
                child: Text('X',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w500,fontSize: 20),),
              ),
            ),
          ),
        ],
      )
      /*end*/
    ],
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';

class GuestSearchResponse {
  final String mid;
  final String mName;
  final int rowNum;
  final String memImage2;

  GuestSearchResponse({
    required this.mid,
    required this.mName,
    required this.rowNum,
    required this.memImage2,
  });

  factory GuestSearchResponse.fromJson(Map<String, dynamic> json) {
    return GuestSearchResponse(
      mid: json["MID"] ?? '',
      mName: json["MName"] ?? '',
      rowNum: json["RowNum"] ?? 0,
      memImage2: json["MemImage2"] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "MID": mid,
      "MName": mName,
      "RowNum": rowNum,
      "MemImage2": memImage2,
    };
  }

  Image getImage() {
    return Image.memory(base64Decode(memImage2));
  }
}

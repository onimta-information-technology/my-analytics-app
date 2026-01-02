import 'dart:convert';

import 'package:flutter/material.dart';

class GuestSearchResponse {
  final String mid;
  final String mName;
  final int rowNum;
  final String memImage2;
  DateTime? lvd;
  final String? gName;
  final String? gRating;
 final String? mGroup;

  GuestSearchResponse({
    required this.mid,
    required this.mName,
    required this.rowNum,
    required this.memImage2,
    this.lvd,
    this.gName,
    this.gRating,
    this.mGroup,
  });

  factory GuestSearchResponse.fromJson(Map<String, dynamic> json) {
    return GuestSearchResponse(
      mid: json["MID"] ?? '',
      mName: json["MName"] ?? '',
      rowNum: json["RowNum"] ?? 0,
      memImage2: json["MemImage2"] ?? '',
      lvd: DateTime.parse(json['LVD']),
      gName: json["GName"],
      gRating: json["G_Rating"],
      mGroup: json["mGroup"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "MID": mid,
      "MName": mName,
      "RowNum": rowNum,
      "MemImage2": memImage2,
      "LVD": lvd?.toIso8601String(),
      "GName": gName,
      "G_Rating": gRating,
      "mGroup": mGroup,
    };
  }

  Image getImage() {
    return Image.memory(base64Decode(memImage2));
  }
}

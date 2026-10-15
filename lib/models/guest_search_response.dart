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
    // LVD sometimes comes back as an empty object ({}) instead of a date
    // string or null — parse only real strings so one row can't break the
    // whole search result.
    final lvdRaw = json['LVD'];
    return GuestSearchResponse(
      mid: json["MID"]?.toString() ?? '',
      mName: json["MName"]?.toString() ?? '',
      rowNum: json["RowNum"] is int
          ? json["RowNum"]
          : int.tryParse('${json["RowNum"]}') ?? 0,
      memImage2: json["MemImage2"]?.toString() ?? '',
      lvd: lvdRaw is String ? DateTime.tryParse(lvdRaw) : null,
      gName: json["GName"]?.toString(),
      gRating: json["G_Rating"]?.toString(),
      mGroup: json["mGroup"]?.toString(),
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

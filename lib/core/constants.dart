import 'package:flutter/material.dart';

class Constants {
  static const Color kPrimaryColor = Color.fromARGB(255, 204, 150, 58);
  static const Color kSecondaryColor = Color.fromARGB(255, 233, 25, 58);
  //static const baseUrl = "https://api.ballyscolombo.com/api/Ballys/CRM";
  //static const laravelAPIbaseUrl = "https://api.mkt.onimtaitsl.com/api";
static const laravelAPIbaseUrl = "https://gift.myanalytics.lk/api";
  // Version check endpoints — picked per logged-in property (see
  // VersionCheckService.checkVersion). Ballys is the default when no
  // property has been selected yet.
  static const versionCheckUrl =
      "https://api.ballyscolombo.com/api/Ballys/ApiVersion_CRM";
  static const bellagioVersionCheckUrl =
      "https://bty.world/api/Bellagio/CRM/ApiVersion_CRM";
  
  // Update URL
  static const iosUpdateUrl = "https://apps.apple.com/lk/app/my-analytics/id6752925402";
static const androidUpdateUrl = "https://play.google.com/store/apps/details?id=com.app.ballys_reservation";
    // Platform IDs for version check
  static const int androidPlatformId = 3;
  static const int iosPlatformId = 4;
}

// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../utils/storage_util.dart';

// class ChatApi {
//   static const String baseUrl = 'https://ballysnotifications.onimtaitsl.com/api';

//   /// Fetch chats for the current user
//   static Future<Map<String, dynamic>> fetchUserChats() async {
//     try {
//       // Get user ID from storage
//       final userId = await StorageUtil.getUserName();
      
//       if (userId == null || userId.isEmpty) {
//         throw Exception('User ID not found in storage');
//       }

//       final response = await http.get(
//         Uri.parse('$baseUrl/chats/user/$userId'),
//         headers: {'Content-Type': 'application/json'},
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = jsonDecode(response.body);
        
//         if (data['success'] == true) {
//           return data;
//         } else {
//           throw Exception('API returned success: false');
//         }
//       } else {
//         throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
//       }
//     } catch (e) {
//       throw Exception('Failed to fetch chats: $e');
//     }
//   }

//   /// Fetch all users (fallback for creating new chats)
//   static Future<Map<String, dynamic>> fetchAllUsers() async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/users'),
//         headers: {'Content-Type': 'application/json'},
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = jsonDecode(response.body);
        
//         if (data['success'] == true) {
//           return data;
//         } else {
//           throw Exception('API returned success: false');
//         }
//       } else {
//         throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
//       }
//     } catch (e) {
//       throw Exception('Failed to fetch users: $e');
//     }
//   }
// }
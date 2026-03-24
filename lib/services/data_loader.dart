import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/camera_model.dart';

class DataLoader {
  /// Loads cameras from a local asset JSON file. Supports either a list
  /// of camera objects or a single camera object.
  static Future<List<CameraInfo>> loadFromAssets(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded
            .map<CameraInfo>((e) => CameraInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (decoded is Map) {
        return [CameraInfo.fromJson(Map<String, dynamic>.from(decoded))];
      }

      return <CameraInfo>[];
    } catch (e) {
      // Bubble up a friendly exception so UI can show errors if needed.
      throw Exception('Error loading cameras from $assetPath: $e');
    }
  }
}

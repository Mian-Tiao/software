import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LocationUploader {
  static final LocationUploader _instance = LocationUploader._internal();
  factory LocationUploader() => _instance;
  LocationUploader._internal();

  StreamSubscription<Position>? _positionStream;

  Future<void> start() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('❌ 找不到 Firebase 使用者');
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final enabled = doc.data()?['locationEnabled'] ?? false;
      debugPrint('✅ locationEnabled: $enabled');

      if (!enabled) return;

      // ✅ 確認權限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          debugPrint('❌ 使用者拒絕定位權限');
          return;
        }
      }

      // ✅ 啟動位置監聽
      debugPrint('✅ 啟動位置上傳');
      _positionStream ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).listen((Position pos) async {
        debugPrint('📍 上傳位置：${pos.latitude}, ${pos.longitude}');
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location': {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'updatedAt': Timestamp.now(),
          }
        });
      });
    } catch (e, stack) {
      debugPrint('❌ 位置上傳錯誤: $e');
      debugPrint(stack.toString());
    }
  }



  void stop() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}

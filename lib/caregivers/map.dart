import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memory/services/safe_zone_setting_page.dart';
import 'dart:math' as math;

class NavHomePage extends StatefulWidget {
  final String careReceiverUid;
  final String careReceiverName;

  const NavHomePage({super.key, required this.careReceiverUid, required this.careReceiverName});

  @override
  State<NavHomePage> createState() => _NavHomePageState();
}

class _NavHomePageState extends State<NavHomePage> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? _careReceiverPosition;
  LatLng? _safeZoneCenter;
  double _safeZoneRadius = 300;
  bool _loading = true;
  bool _deviceLocationOn = false;   // 裝置定位是否開啟
  bool _safeZoneMonitoringOn = true; // 是否啟用安全範圍監測（預設 true）


  @override
  void initState() {
    super.initState();
    debugPrint('🧭 careReceiverUid: ${widget.careReceiverUid}');
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadSafeZone(),
      _initCurrentPosition(),
      _loadCareReceiverLocation(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _initCurrentPosition() async {
    debugPrint('📍 開始取得目前位置');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ 定位服務未啟用');
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ 使用者拒絕定位權限');
        return;
      }
    }

    Position pos = await Geolocator.getCurrentPosition();
    debugPrint('✅ 拿到目前位置: ${pos.latitude}, ${pos.longitude}');
    if (!mounted) return;
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });

    _tryMoveToCareReceiver();
  }

  void _applySafeZoneFromResult(Map r) async {
    final centerMap = r['center'] as Map;
    final LatLng newCenter = LatLng(
      (centerMap['lat'] as num).toDouble(),
      (centerMap['lng'] as num).toDouble(),
    );
    final double newRadius = (r['radius'] as num).toDouble();
    if (!mounted) return;

    setState(() {
      _safeZoneCenter = newCenter;
      _safeZoneRadius = newRadius;
    });

    // 把鏡頭移到新的安全區中心（initialCameraPosition 不會自動改）
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(newCenter, 16),
    );
  }

  Future<void> _loadCareReceiverLocation() async {
    debugPrint('🚀 開始載入被照顧者位置');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.careReceiverUid)
          .get();

      final data = doc.data();
      debugPrint('📍 Firebase 拿到資料: $data');

      if (data != null && data['location'] != null) {
        final lat = data['location']['lat'];
        final lng = data['location']['lng'];
        if (!mounted) return;
        setState(() {
          _careReceiverPosition = LatLng(lat, lng);
        });

        _tryMoveToCareReceiver();
      }
    } catch (e, stack) {
      debugPrint('🔥 載入被照顧者位置錯誤: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _loadSafeZone() async {
    debugPrint('🟢 載入 safeZone 資料...');
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.careReceiverUid);
      final snap = await docRef.get();
      if (!mounted) return;

      final data = snap.data() ?? {};
      final zone = Map<String, dynamic>.from(data['safeZone'] ?? {});

      // 1) 裝置定位：root 或 nested 只要有一個 true 就算開
      final rootLocOn   = (data['locationEnabled'] == true);
      final nestedLocOn = (data['location'] is Map) && (data['location']['locationEnabled'] == true);
      final deviceLocationOn = rootLocOn || nestedLocOn;

      // 2) 安全範圍監測開關（預設 true，只有明確 false 才關）
      final safeZoneMonitoringOn = !(zone['locationEnabled'] == false);

      // 圓心/半徑
      final double? lat = (zone['lat'] is num) ? (zone['lat'] as num).toDouble() : null;
      final double? lng = (zone['lng'] is num) ? (zone['lng'] as num).toDouble() : null;
      final double radius = (zone['radius'] is num) ? (zone['radius'] as num).toDouble() : 300.0;

      setState(() {
        _deviceLocationOn     = deviceLocationOn;       // ← 用這個判斷「是否開啟定位」
        _safeZoneMonitoringOn = safeZoneMonitoringOn;   // ← 用這個控制是否評估在/離開範圍
        _safeZoneCenter       = (lat != null && lng != null) ? LatLng(lat, lng) : null;
        _safeZoneRadius       = radius;
      });

      debugPrint('📄 deviceLocationOn=$_deviceLocationOn, '
          'safeZoneMonitoringOn=$_safeZoneMonitoringOn, '
          'center=$_safeZoneCenter, radius=$_safeZoneRadius');
    } catch (e) {
      debugPrint('❌ 載入 safeZone 失敗: $e');
    }
  }





  void _tryMoveToCareReceiver() {
    if (_mapController != null && _careReceiverPosition != null) {
      debugPrint('📌 移動鏡頭到被照顧者位置');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_careReceiverPosition!, 16),
      );
    }
  }

  // 小工具：統一資訊貼片樣式（白底+冷綠邊框）
  Widget _infoChip({required IconData icon, required String text, Color color = const Color(0xFF28965A)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF77A88D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

// 新增：大橫幅（警示/提示用）

  Widget _noLocationView({required String name}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF77A88D), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, color: Color(0xFFFF6670)),
            const SizedBox(width: 10),
            Text(
              '$name 尚未開啟定位',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_loading || _currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } 

    final bool hasSafeZone = _safeZoneCenter != null && _safeZoneRadius > 0;
    final bool canJudgeInside = _deviceLocationOn && hasSafeZone && _careReceiverPosition != null;
    final bool isInside = canJudgeInside
        ? _distanceMeters(_careReceiverPosition!, _safeZoneCenter!) <= _safeZoneRadius
        : false;

    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA),
      appBar: AppBar(
        title: const Text("被照顧者位置", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF28965A),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定安全範圍',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SafeZoneSettingPage(careReceiverUid: widget.careReceiverUid),
                ),
              );
              if (!mounted) return;
              if (result is Map && result['updated'] == true) {
                _applySafeZoneFromResult(result);
              } else if (result == 'updated') {
                await _loadSafeZone();
                if (!mounted) return;
                setState(() {});
                if (_safeZoneCenter != null) {
                  await _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_safeZoneCenter!, 16),
                  );
                }
              }
            },
          ),
        ],
      ),

      // ✅ 只要未開定位 → 整頁只有提示，不渲染地圖
      body: !_deviceLocationOn
          ? _noLocationView(name:widget.careReceiverName)
          : (_currentPosition == null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            key: ValueKey(
              'map:${_careReceiverPosition?.latitude}_${_careReceiverPosition?.longitude}_${_safeZoneCenter?.latitude}_${_safeZoneCenter?.longitude}_$_safeZoneRadius',
            ),
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _tryMoveToCareReceiver();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId("current"),
                position: _currentPosition!,
                infoWindow: const InfoWindow(title: "我的位置"),
              ),
              if (_careReceiverPosition != null)
                Marker(
                  markerId: const MarkerId("careReceiver"),
                  position: _careReceiverPosition!,
                  infoWindow: const InfoWindow(title: "被照顧者"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
            },
            circles: !hasSafeZone
                ? {}
                : {
              Circle(
                circleId: const CircleId("safeZone"),
                center: _safeZoneCenter!,
                radius: _safeZoneRadius,
                fillColor: const Color(0xFF2CEAA3).withAlpha(48),
                strokeColor: const Color(0xFF28965A),
                strokeWidth: 2,
              ),
            },
          ),

          if (hasSafeZone)
            Positioned(
              top: 12,
              right: 12,
              child: _infoChip(
                icon: Icons.radar,
                text: '半徑 ${_safeZoneRadius.toStringAsFixed(0)} m',
              ),
            ),
          if (canJudgeInside)
            Positioned(
              top: 12,
              left: 12,
              child: _infoChip(
                icon: isInside ? Icons.check_circle : Icons.error_outline,
                text: isInside ? '範圍內' : '已超出',
                color: isInside ? const Color(0xFF28965A) : const Color(0xFFFF6670),
              ),
            ),
        ],
      ),
    );
  }



// 距離（公尺）：若你在別處已實作可沿用
  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return R * c;
  }
  @override
  void dispose() {
    debugPrint("🧹 NavHomePage dispose → 清理資源");

    // 地圖控制器要釋放
    _mapController?.dispose();
    _mapController = null;

    // ⚠️ 如果之後改用 Firestore .snapshots().listen()
    // 就要在這裡 cancel 掉 subscription，避免 callback 還跑 setState

    super.dispose();
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SafeZoneSettingPage extends StatefulWidget {
  final String careReceiverUid;

  const SafeZoneSettingPage({super.key, required this.careReceiverUid});

  @override
  State<SafeZoneSettingPage> createState() => _SafeZoneSettingPageState();
}

class _SafeZoneSettingPageState extends State<SafeZoneSettingPage> {
  GoogleMapController? _mapController;
  LatLng? _safeZoneCenter;
  double _safeZoneRadius = 300;
  bool _isLoading = true;

  // 半徑輸入框
  final TextEditingController _radiusController = TextEditingController();
  static const double _minRadius = 20;    // 可自行調整
  static const double _maxRadius = 3000;  // 可自行調整

  @override
  void initState() {
    super.initState();
    _loadSafeZoneOrFallback();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  // === 主要載入流程 ===
  // 1) 有 safeZone 且含 lat/lng → 用它
  // 2) 否則 → 用 users/{uid}.location 當中心
  // 3) 再否 → 嘗試 users/{uid}/locations 最新一筆
  // 4) 若仍沒有 → 等使用者在地圖上點一下再設定
  Future<void> _loadSafeZoneOrFallback() async {
    LatLng? center;
    double radius = _safeZoneRadius;

    try {
      final userRef =
      FirebaseFirestore.instance.collection('users').doc(widget.careReceiverUid);
      final snap = await userRef.get();
      final data = snap.data();

      if (data != null && data['safeZone'] != null) {
        final zone = data['safeZone'];
        final lat = (zone['lat'] as num?)?.toDouble();
        final lng = (zone['lng'] as num?)?.toDouble();
        final r = (zone['radius'] as num?)?.toDouble();

        // 如果 safeZone 有完整座標 → 直接採用
        if (lat != null && lng != null) {
          center = LatLng(lat, lng);
          if (r != null) radius = r;
        } else {
          // 沒有座標（像你截圖只存了 radius）→ 退回用最新位置
          center = await _loadLatestCareReceiverLocation(userRef);
          if (r != null) radius = r;
        }
      } else {
        // 沒有 safeZone → 退回用最新位置
        center = await _loadLatestCareReceiverLocation(userRef);
      }
    } catch (e) {
      debugPrint('❌ 載入 safeZone/location 錯誤: $e');
    }

    if (!mounted) return;

    setState(() {
      _safeZoneCenter = center;        // 可能為 null（等待使用者點地圖）
      _safeZoneRadius = radius;
      _radiusController.text = radius.toStringAsFixed(0);
      _isLoading = false;
    });

    // 地圖建立後才會有 controller，這裡只在已經有 controller 且 center 非空才動畫
    _animateToCenterWithRadius();
  }

  /// 嘗試讀 users/{uid}.location = {lat, lng, updatedAt}
  /// 其次讀 users/{uid}/locations 最新一筆（欄位名用 'timestamp' 可自行改）
  Future<LatLng?> _loadLatestCareReceiverLocation(DocumentReference userRef) async {
    try {
      final user = (await userRef.get()).data() as Map<String, dynamic>?;
      if (user != null && user['location'] != null) {
        final loc = user['location'] as Map<String, dynamic>;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

      // 子集合備援
      final q = await userRef
          .collection('locations')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('❌ 讀取最新位置失敗: $e');
    }
    return null;
  }

  Future<void> _saveSafeZone() async {
    if (_safeZoneCenter == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先在地圖上點一下，設定安全區中心')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.careReceiverUid)
        .set({
      'safeZone': {
        'lat': _safeZoneCenter!.latitude,
        'lng': _safeZoneCenter!.longitude,
        'radius': _safeZoneRadius,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已儲存安全範圍：${_safeZoneRadius.toStringAsFixed(0)} m')),
    );

    Navigator.pop(context, {
      'updated': true,
      'center': {
        'lat': _safeZoneCenter!.latitude,
        'lng': _safeZoneCenter!.longitude,
      },
      'radius': _safeZoneRadius,
    });
  }

  // === 地圖/半徑工具 ===

  // Haversine 公式：計算兩點距離（公尺）
  double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const double R = 6371000;
    final double lat1 = p1.latitude * (math.pi / 180);
    final double lat2 = p2.latitude * (math.pi / 180);
    final double dLat = (p2.latitude - p1.latitude) * (math.pi / 180);
    final double dLng = (p2.longitude - p1.longitude) * (math.pi / 180);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // 依半徑估算縮放；100m≈18、300m≈16、1000m≈14（可再調）
  double _zoomForRadius(double radiusMeters) {
    final r = radiusMeters.clamp(_minRadius, _maxRadius);
    final zoom = 16.5 - math.log(r) / math.ln10;
    return zoom.clamp(12.0, 20.0);
  }

  void _animateToCenterWithRadius() {
    if (_safeZoneCenter == null || _mapController == null) return;
    try {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _safeZoneCenter!,
            zoom: _zoomForRadius(_safeZoneRadius),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ animateCamera 錯誤: $e');
    }
  }

  // 設定半徑（含限制、同步輸入框）
  void _setRadius(double value, {bool syncText = true}) {
    final r = value.clamp(_minRadius, _maxRadius).toDouble();
    setState(() {
      _safeZoneRadius = r;
      if (syncText) {
        _radiusController.text = r.toStringAsFixed(0);
      }
    });
    _animateToCenterWithRadius();
  }

  // 輸入框提交時套用
  void _applyRadiusFromInput() {
    final v = _radiusController.text.trim();
    final parsed = double.tryParse(v);
    if (parsed == null) {
      _radiusController.text = _safeZoneRadius.toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入有效的半徑數值')),
      );
      return;
    }
    _setRadius(parsed, syncText: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA),
      appBar: AppBar(
        title: const Text('設定安全範圍'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // 以「最新上傳位置」置中
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: '以最新位置置中',
            onPressed: () async {
              setState(() => _isLoading = true);
              final userRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.careReceiverUid);
              final messenger = ScaffoldMessenger.of(context);
              final latest = await _loadLatestCareReceiverLocation(userRef);
              if (!mounted) return;
              setState(() {
                _safeZoneCenter = latest ?? _safeZoneCenter;
                _isLoading = false;
              });
              _animateToCenterWithRadius();
              if (latest == null) {
                if (!mounted) return; // 保險用
                messenger.showSnackBar(
                  const SnackBar(content: Text('找不到被照顧者的最新位置')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '儲存並返回',
            onPressed: _saveSafeZone,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 地圖：點擊調半徑；拖曳 Marker 可移動中心
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _safeZoneCenter ?? const LatLng(23.6978, 120.9605), // 台灣中心備援
                zoom: _zoomForRadius(_safeZoneRadius),
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // controller 準備好後再對齊一次
                _animateToCenterWithRadius();
              },
              onTap: (LatLng tappedPoint) {
                if (_safeZoneCenter == null) {
                  setState(() => _safeZoneCenter = tappedPoint);
                  _animateToCenterWithRadius();
                } else {
                  final newRadius =
                  _calculateDistanceMeters(_safeZoneCenter!, tappedPoint);
                  _setRadius(newRadius); // 同步輸入框
                }
              },
              markers: {
                if (_safeZoneCenter != null)
                  Marker(
                    markerId: const MarkerId("safeZoneCenter"),
                    position: _safeZoneCenter!,
                    draggable: true,
                    onDragEnd: (newPos) {
                      setState(() => _safeZoneCenter = newPos);
                      _animateToCenterWithRadius();
                    },
                    infoWindow: const InfoWindow(title: '安全區中心'),
                  )
              },
              circles: {
                if (_safeZoneCenter != null)
                  Circle(
                    circleId: const CircleId('safeZone'),
                    center: _safeZoneCenter!,
                    radius: _safeZoneRadius,
                    fillColor: Colors.green.withAlpha(80),
                    strokeColor: Colors.green,
                    strokeWidth: 2,
                  )
              },
            ),
          ),

          // 控制區：顯示目前半徑 + 可輸入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '安全範圍半徑：${_safeZoneRadius.toInt()} 公尺',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _radiusController,
                        style: const TextStyle(color: Colors.black),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: false,
                        ),
                        decoration: InputDecoration(
                          labelText: '輸入半徑（$_minRadius ~ $_maxRadius 公尺）',
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.radar),
                        ),
                        onSubmitted: (_) => _applyRadiusFromInput(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _applyRadiusFromInput,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('套用'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _saveSafeZone,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存並返回'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_safeZoneCenter == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '提示：尚未偵測到被照顧者位置，請在地圖上點一下設定安全區中心。',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

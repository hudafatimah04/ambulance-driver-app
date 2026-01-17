
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'config/supabase_config.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
);

  

  runApp(const AmbulanceDriverApp());
}

enum DriverState {
  idle,
  incomingRequest,
  navigatingToPickup,
  waitingForHospital, // 🆕 VERY IMPORTANT
  navigatingToHospital,
  completed
}


enum PatientPriority { critical, high, medium, low }

enum AmbulanceType { basic, icu, cardiac }

class DriverProfile {
  final String name;
  final String ambulanceId;
  final AmbulanceType type;

  DriverProfile({
    required this.name,
    required this.ambulanceId,
    required this.type,
  });

  String get typeLabel {
    switch (type) {
      case AmbulanceType.basic:
        return 'Basic Life Support';
      case AmbulanceType.icu:
        return 'ICU Ambulance';
      case AmbulanceType.cardiac:
        return 'Cardiac Care';
    }
  }
}

class EmergencyRequest {
  final String id;
  final String emergencyType;
  final PatientPriority priority;
  final String patientStatus;
  final LatLng pickupLocation;
  final String pickupAddress;
  final String pickupLandmark;
  final LatLng hospitalLocation;
  final String hospitalName;
  final double distanceKm;
  final int etaMinutes;

  EmergencyRequest({
    required this.id,
    required this.emergencyType,
    required this.priority,
    required this.patientStatus,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.pickupLandmark,
    required this.hospitalLocation,
    required this.hospitalName,
    required this.distanceKm,
    required this.etaMinutes,
  });
}

class TripSummary {
  final double distanceCovered;
  final int timeTaken;
  final String patientPriority;
  final String emergencyType;

  TripSummary({
    required this.distanceCovered,
    required this.timeTaken,
    required this.patientPriority,
    required this.emergencyType,
  });
}

class AmbulanceDriverApp extends StatelessWidget {
  const AmbulanceDriverApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambulance Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          primary: const Color(0xFF1DB954),
          secondary: const Color(0xFF0F7A3D),
          error: const Color(0xFFE53935),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  AmbulanceType _selectedType = AmbulanceType.basic;

 Future<void> _login() async {

    if (_nameController.text.trim().isEmpty ||
        _idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

   final driverId = _idController.text.trim().toUpperCase();

final profile = DriverProfile(
  name: _nameController.text.trim(),
  ambulanceId: driverId,
  type: _selectedType,
);

    final supabase = Supabase.instance.client;

final result = await supabase.from('drivers').upsert({
  'driver_id': driverId,

  'name': _nameController.text.trim(),
  'ambulance_type': _selectedType.name.toUpperCase(),
  'is_online': true,
  'last_seen': DateTime.now().toIso8601String(),
}).select();

debugPrint('LOGIN UPSERT RESULT: $result');


    if (!mounted) return;

Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => DriverHomeScreen(profile: profile),
  ),
);

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min, // IMPORTANT
        crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.local_hospital,
                size: 80,
                color: Color(0xFF1DB954),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ambulance Driver',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Emergency Response System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Driver Name',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'Ambulance ID',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonFormField<AmbulanceType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Ambulance Type',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    items: AmbulanceType.values
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(_getTypeLabel(type)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'START SHIFT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(AmbulanceType type) {
    switch (type) {
      case AmbulanceType.basic:
        return 'Basic Life Support';
      case AmbulanceType.icu:
        return 'ICU Ambulance';
      case AmbulanceType.cardiac:
        return 'Cardiac Care';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }
}

class DriverHomeScreen extends StatefulWidget {
  final DriverProfile profile;

  const DriverHomeScreen({Key? key, required this.profile}) : super(key: key);

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with TickerProviderStateMixin {
  DriverState _currentState = DriverState.idle;
  final MapController _mapController = MapController();
  bool _isFollowingAmbulance = true;
  LatLng? _ambulanceLocation;
  Timer? _heartbeatTimer;
  int _routeIndex = 0;
double _totalRouteDistance = 0;
int _totalRouteEta = 0;
String? _lastRejectedEmergencyId;
bool _isBottomCardExpanded = true;






  EmergencyRequest? _currentRequest;
  DateTime? _tripStartTime;
  double _remainingDistance = 0;
  int _remainingEta = 0;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  final supabase = Supabase.instance.client;

  
  List<LatLng> _currentRoutePoints = [];
 
  Timer? _movementTimer;
  
  bool _showTrafficBanner = false;
  Timer? _trafficBannerTimer;
  Timer? _pollingTimer;
  RealtimeChannel? _emergencyChannel;
  RealtimeChannel? _hospitalChannel;
  bool _fetchingEmergency = false;






 

@override
void initState() {
  super.initState();

    // 🔥 REALTIME LISTENER FOR NEW EMERGENCIES
  _emergencyChannel = supabase
      .channel('emergencies-channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'emergencies',
        callback: (payload) {
          // Only fetch if driver is free
          if (_currentState == DriverState.idle) {
            fetchEmergency();
          }
        },
      )
      .subscribe();

  // fire-and-forget (safe)
  _unlockPreviousEmergencies();

requestLocationPermission().then((_) async {
  await updateLiveLocation();
  _initializeIdleState();
  fetchEmergency();
});

_heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
  supabase.from('drivers').update({
    'last_seen': DateTime.now().toIso8601String(),
  }).eq('driver_id', widget.profile.ambulanceId);
});


  _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    if (_currentState == DriverState.idle) {
      fetchEmergency();
    }
  });
}

@override
void dispose() {
  // 🔥 Fire-and-forget driver offline update
  unawaited(
    supabase.from('drivers').update({
      'is_online': false,
      'current_emergency': null,
    }).eq('driver_id', widget.profile.ambulanceId),
  );

  // 🧹 Cleanup resources
  _heartbeatTimer?.cancel();
  _pollingTimer?.cancel();
  _movementTimer?.cancel();
  _trafficBannerTimer?.cancel();
  _emergencyChannel?.unsubscribe();
  _hospitalChannel?.unsubscribe(); // ✅ ADD THIS LINE

  super.dispose();
}

Future<void> updateLiveLocation() async {
  try {
    debugPrint('📍 Requesting GPS position...');
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint('✅ GPS FOUND: ${pos.latitude}, ${pos.longitude}');

    _ambulanceLocation = LatLng(pos.latitude, pos.longitude);

    await supabase.from('drivers').update({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    }).eq('driver_id', widget.profile.ambulanceId);

  } catch (e) {
    debugPrint('❌ Live location update failed: $e');
  }
}


Future<void> _unlockPreviousEmergencies() async {
  try {
    await supabase
  .from('emergencies')
  .update({'status': 'SEARCHING', 'locked_by': null})
  .eq('locked_by', widget.profile.ambulanceId)
  .eq('status', 'LOCKED');

  } catch (e) {
    debugPrint('Failed to unlock emergencies: $e');
  }
}


Future<void> requestLocationPermission() async {
 bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
  await Geolocator.openLocationSettings();
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services disabled');
  }
}



  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
  }
await Geolocator.checkPermission();


}


Future<void> fetchEmergency() async {
  if (_fetchingEmergency) return;
  _fetchingEmergency = true;

  if (_currentState != DriverState.idle) {
    _fetchingEmergency = false;
    return;
  }

  final data = await supabase
      .from('emergencies')
      .select()
      .eq('status', 'SEARCHING')
      .order('created_at', ascending: false)
      .limit(1);

  if (data.isEmpty) {
    _fetchingEmergency = false;
    return;
  }

  final e = data[0];
  if (e['id'] == _lastRejectedEmergencyId) {
  _fetchingEmergency = false;
  return;
}


  final updated = await supabase
      .from('emergencies')
      .update({
        'status': 'LOCKED',
        'locked_by': widget.profile.ambulanceId,
      })
      .eq('id', e['id'])
      .eq('status', 'SEARCHING')
      .select();

  if (updated.isEmpty) {
    _fetchingEmergency = false;
    return;
  }

  setState(() {
    _currentRequest = EmergencyRequest(
      id: e['id'],
      emergencyType: e['emergency_type'],
      priority: PatientPriority.critical,
      patientStatus: e['patient_status'],
      pickupLocation: LatLng(
  e['pickup_latitude'],
  e['pickup_longitude'],
),

      pickupAddress:
    'Lat ${e['pickup_latitude'].toStringAsFixed(5)}, '
    'Lng ${e['pickup_longitude'].toStringAsFixed(5)}',
pickupLandmark: 'Approximate location',

      hospitalLocation: const LatLng(0, 0),
      hospitalName: "Waiting for hospital",
      distanceKm: 0,
      etaMinutes: 0,
    );
    _currentState = DriverState.incomingRequest;
  });

  if (_ambulanceLocation != null) {
    _fetchAndDisplayRoute(
      _ambulanceLocation!,
      _currentRequest!.pickupLocation,
    );
  }

  _fetchingEmergency = false;
}


  void _initializeIdleState() {
    if (_ambulanceLocation == null) return;
    setState(() {
      _markers = [
        Marker(
          point: _ambulanceLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.local_shipping,
            color: Color(0xFF1DB954),
            size: 40,
          ),
        ),
      ];
      _polylines = [];
    });
  }

 /* void _simulateIncomingRequest() {
    final mockRequest = EmergencyRequest(
      id: 'ER-${DateTime.now().millisecondsSinceEpoch}',
      emergencyType: 'Cardiac Emergency',
      priority: PatientPriority.critical,
      patientStatus: 'Critical',
      pickupLocation: LatLng(12.9716, 77.5946),
      pickupAddress: 'MG Road, Bangalore',
      pickupLandmark: 'Near Trinity Metro Station',
      hospitalLocation: LatLng(12.9698, 77.7500),
      hospitalName: 'Apollo Hospital, Whitefield',
      distanceKm: 4.2,
      etaMinutes: 8,
    );

    setState(() {
      _currentState = DriverState.incomingRequest;
      _currentRequest = mockRequest;
    });
    
    _fetchAndDisplayRoute(_ambulanceLocation, mockRequest.pickupLocation);
  }
*/

  Future<void> _fetchAndDisplayRoute(LatLng start, LatLng end) async {
    if (_currentRequest == null) return;

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        final routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        
        _totalRouteDistance = data['routes'][0]['distance'] / 1000;
final distance = _totalRouteDistance;

        _totalRouteEta =
    (data['routes'][0]['duration'] / 60).round();

final duration = _totalRouteEta;

        _routeIndex = 0;

        setState(() {
          _currentRoutePoints = routePoints;
          
          _remainingDistance = distance;
          _remainingEta = duration;
          _currentRequest = EmergencyRequest(
  id: _currentRequest!.id,
  emergencyType: _currentRequest!.emergencyType,
  priority: _currentRequest!.priority,
  patientStatus: _currentRequest!.patientStatus,
  pickupLocation: _currentRequest!.pickupLocation,
  pickupAddress: _currentRequest!.pickupAddress,
  pickupLandmark: _currentRequest!.pickupLandmark,
  hospitalLocation: _currentRequest!.hospitalLocation,
  hospitalName: _currentRequest!.hospitalName,
  distanceKm: distance,
  etaMinutes: duration,
);

          
          _markers = [
            Marker(
              point: _ambulanceLocation!,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.local_shipping,
                color: Color(0xFF1DB954),
                size: 40,
              ),
            ),
            Marker(
              point: end,
              width: 40,
              height: 40,
              child: Icon(
                _currentState == DriverState.incomingRequest ? Icons.location_on : Icons.local_hospital,
                color: _currentState == DriverState.incomingRequest ? const Color(0xFFE53935) : const Color(0xFF1976D2),
                size: 40,
              ),
            ),
          ];
          
          _polylines = _createTrafficSegments(routePoints);
        });
        
        _animateCameraToShowRoute(start, end);
      }
    } catch (e) {
      debugPrint('Routing failed: $e');

      _createFallbackRoute(start, end);
    }
  }

  List<Polyline> _createTrafficSegments(List<LatLng> points) {
    if (points.length < 2) return [];
    
    final segments = <Polyline>[];
    final segmentSize = math.max(1, points.length ~/ 5);
    
    for (int i = 0; i < points.length - 1; i += segmentSize) {
      final endIndex = math.min(i + segmentSize + 1, points.length);
      final segmentPoints = points.sublist(i, endIndex);
      
      final random = math.Random(i);
      final trafficLevel = random.nextDouble();
      
      Color segmentColor;
      if (trafficLevel < 0.6) {
        segmentColor = const Color(0xFF1DB954);
      } else if (trafficLevel < 0.85) {
        segmentColor = const Color(0xFFFB8C00);
      } else {
        segmentColor = const Color(0xFFE53935);
      }
      
      segments.add(Polyline(
        points: segmentPoints,
        color: segmentColor,
        strokeWidth: 4.0,
      ));
    }
    
    return segments;
  }

  void _createFallbackRoute(LatLng start, LatLng end) {
    setState(() {
      _currentRoutePoints = [start, end];
      _polylines = [
        Polyline(
          points: [start, end],
          color: const Color(0xFF1DB954),
          strokeWidth: 4.0,
        ),
      ];
      
      _markers = [
        Marker(
          point: _ambulanceLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.local_shipping,
            color: Color(0xFF1DB954),
            size: 40,
          ),
        ),
        Marker(
          point: end,
          width: 40,
          height: 40,
          child: Icon(
            _currentState == DriverState.incomingRequest ? Icons.location_on : Icons.local_hospital,
            color: _currentState == DriverState.incomingRequest ? const Color(0xFFE53935) : const Color(0xFF1976D2),
            size: 40,
          ),
        ),
      ];
    });
    
    _animateCameraToShowRoute(start, end);
  }
Future<void> _acceptRequest() async {
  if (_currentRequest == null) return;

  try {
    // 1️⃣ Create assignment record
    await supabase.from('ambulance_assignments').insert({
      'emergency_id': _currentRequest!.id,
      'driver_id': widget.profile.ambulanceId,
      'status': 'ACCEPTED',
    });

    // 2️⃣ Mark emergency as assigned
    await supabase
        .from('emergencies')
        .update({'status': 'ASSIGNED'})
        .eq('id', _currentRequest!.id)
        .eq('locked_by', widget.profile.ambulanceId);

    // 3️⃣ Attach emergency to driver
    await supabase.from('drivers').update({
      'current_emergency': _currentRequest!.id,
    }).eq('driver_id', widget.profile.ambulanceId);

    debugPrint('✅ Emergency accepted successfully');

  } catch (e) {
    debugPrint('❌ Accept request failed: $e');
    return; // 🚫 STOP if anything fails
  }

  // ✅ UI state update (NO backend calls here)
  setState(() {
    _currentState = DriverState.navigatingToPickup;
    _tripStartTime = DateTime.now();
    _routeIndex = 0; // reset route progress
  });

  // ✅ Start movement + traffic simulation
  _startAmbulanceMovement();
  _startTrafficSimulation();
}

void _startAmbulanceMovement() {
  debugPrint('🚑 MOVEMENT STARTED');

  _movementTimer?.cancel();

  _movementTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
    if (_currentRoutePoints.isEmpty ||
    _routeIndex >= _currentRoutePoints.length) {
  timer.cancel();

  setState(() {
    _remainingDistance = 0;
    _remainingEta = 0;
  });

  return;
}


    setState(() {
      // 🔥 Move ambulance along route
      _ambulanceLocation = _currentRoutePoints[_routeIndex];
supabase.from('drivers').update({
  'latitude': _ambulanceLocation!.latitude,
  'longitude': _ambulanceLocation!.longitude,
}).eq('driver_id', widget.profile.ambulanceId);
supabase.from('ambulance_locations').upsert(
  {
    'driver_id': widget.profile.ambulanceId,
    'latitude': _ambulanceLocation!.latitude,
    'longitude': _ambulanceLocation!.longitude,
    'timestamp': DateTime.now().toIso8601String(),
  },
  onConflict: 'driver_id',
).then((_) {
  debugPrint('📍 ambulance_locations UPDATED');
}).catchError((e) {
  debugPrint('❌ ambulance_locations UPDATE FAILED: $e');
});






      // 🔥 Progress ratio (0 → 1)
      final progress = _routeIndex / _currentRoutePoints.length;

      // 🔥 Update distance & ETA realistically
      _remainingDistance = _totalRouteDistance * (1 - progress);
     _remainingEta =
    math.max(1, (_totalRouteEta * (1 - progress)).round());

      // 🔥 Move map camera
      if (_isFollowingAmbulance) {
        try {
          final currentZoom = _mapController.camera.zoom;
          _animatedMove(_ambulanceLocation!, currentZoom);
        } catch (_) {
          _animatedMove(_ambulanceLocation!, 16.0);
        }
      }

      // 🔥 Update marker
      _markers = [
        Marker(
          point: _ambulanceLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.local_shipping,
            color: Color(0xFF1DB954),
            size: 40,
          ),
        ),
      ];

      _routeIndex++;
    });
  });
}


  Future<void> _animatedMove(LatLng dest, double zoom) async {
  final latTween = Tween<double>(
    begin: _mapController.camera.center.latitude,
    end: dest.latitude,
  );
  final lngTween = Tween<double>(
    begin: _mapController.camera.center.longitude,
    end: dest.longitude,
  );
  final zoomTween = Tween<double>(
    begin: _mapController.camera.zoom,
    end: zoom,
  );

  var controller = AnimationController(
    duration: const Duration(milliseconds: 700),
    vsync: this,
  );

  Animation<double> animation =
      CurvedAnimation(parent: controller, curve: Curves.easeInOut);

  controller.addListener(() {
    _mapController.move(
      LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
      zoomTween.evaluate(animation),
    );
  });

  controller.addStatusListener((status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      controller.dispose();
    }
  });

  controller.forward();
}

  void _startTrafficSimulation() {
    _trafficBannerTimer?.cancel();
    
    final random = math.Random();
    _trafficBannerTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (random.nextDouble() > 0.6) {
        setState(() {
          _showTrafficBanner = true;
          _remainingEta += random.nextInt(3) + 1;
        });
        
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showTrafficBanner = false;
            });
          }
        });
      }
    });
  }

 void _rejectRequest() async {
  if (_currentRequest == null) return;

 await supabase.from('emergencies').update({
  'status': 'SEARCHING',
  'locked_by': null
})
.eq('id', _currentRequest!.id)
.eq('locked_by', widget.profile.ambulanceId);


  await supabase.from('drivers').update({
    'current_emergency': null
  }).eq('driver_id', widget.profile.ambulanceId);
  _lastRejectedEmergencyId = _currentRequest!.id;

  setState(() {
    _currentState = DriverState.idle;
    _currentRequest = null;
    _initializeIdleState();
  });
}

Future<void> _arrivedAtPickup() async {
  if (_currentRequest == null) return;

  // 🔥 UPDATE BACKEND: driver reached patient
  await supabase.from('ambulance_assignments').update({
    'status': 'ARRIVED_AT_PICKUP',
  }).eq('emergency_id', _currentRequest!.id);

  // 🛑 Stop movement
  _movementTimer?.cancel();
  _trafficBannerTimer?.cancel();

  setState(() {
    _currentState = DriverState.waitingForHospital;
    _remainingDistance = 0;
    _remainingEta = 0;
  });

  // 🧹 Clean previous listener
  await _hospitalChannel?.unsubscribe();

  // 🔥 REALTIME LISTENER (CORRECT FILTER SYNTAX)
  _hospitalChannel = supabase
      .channel('hospital-${_currentRequest!.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'emergency_hospital',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'emergency_id',
          value: _currentRequest!.id,
        ),
        callback: (payload) {
          debugPrint('🔥 REALTIME EVENT RECEIVED');
          debugPrint('NEW: ${payload.newRecord}');
          fetchHospital();
        },
      )
      .subscribe();

  // 🛡️ SAFETY: fetch once in case realtime misses
  await fetchHospital();
}

 Future<void> fetchHospital() async {
  if (_currentRequest == null) return;

  final data = await supabase
      .from('emergency_hospital')
      .select()
      .eq('emergency_id', _currentRequest!.id)
      .limit(1);

  if (data.isEmpty) return;

final h = data[0];

debugPrint('🏥 emergency_hospital row received: $h');

final status = (h['status'] as String).toUpperCase().trim();

if (status != 'CONFIRMED') {
  debugPrint('⏳ Hospital status is $status, still waiting...');
  return;
}

// 🔥 ADD THIS LINE RIGHT HERE
debugPrint('✅ HOSPITAL CONFIRMED — STARTING ROUTE');



  // ✅ FETCH HOSPITAL FIRST
  final hospital = await supabase
      .from('hospitals_database')
      .select()
      .eq('hospital_id', h['hospital_id'])
      .single();

  // ✅ NOW route can be drawn
  await _fetchAndDisplayRoute(
    _currentRequest!.pickupLocation,
    LatLng(hospital['latitude'], hospital['longitude']),
  );

  // ✅ UPDATE UI STATE
  setState(() {
    _currentRequest = EmergencyRequest(
      id: _currentRequest!.id,
      emergencyType: _currentRequest!.emergencyType,
      priority: _currentRequest!.priority,
      patientStatus: _currentRequest!.patientStatus,
      pickupLocation: _currentRequest!.pickupLocation,
      pickupAddress: _currentRequest!.pickupAddress,
      pickupLandmark: _currentRequest!.pickupLandmark,
      hospitalLocation: LatLng(
        hospital['latitude'],
        hospital['longitude'],
      ),
      hospitalName: hospital['hospital_name'],
      distanceKm: _currentRequest!.distanceKm,
      etaMinutes: _currentRequest!.etaMinutes,
    );
  });
    // 🚑 NOW START MOVING TO HOSPITAL (ONLY AFTER CONFIRMATION)
  setState(() {
    _currentState = DriverState.navigatingToHospital;
  });
_routeIndex = 0; 
  _startAmbulanceMovement();
  _startTrafficSimulation();


  
}

Future<void> _arrivedAtHospital() async {

    _movementTimer?.cancel();
    _trafficBannerTimer?.cancel();
    
    if (_currentRequest == null || _tripStartTime == null) return;

    final timeTaken = DateTime.now().difference(_tripStartTime!).inMinutes;
    final summary = TripSummary(
      distanceCovered: _currentRequest!.distanceKm,

      timeTaken: timeTaken > 0 ? timeTaken : 26,
      patientPriority: _currentRequest!.patientStatus,
      emergencyType: _currentRequest!.emergencyType,
    );

    setState(() {
      _currentState = DriverState.completed;
    });
    supabase.from('drivers').update({
  'current_emergency': null
}).eq('driver_id', widget.profile.ambulanceId);

supabase.from('emergencies').update({
  'status': 'COMPLETED'
}).eq('id', _currentRequest!.id);

await supabase.from('ambulance_assignments').update({
  'status': 'COMPLETED',
}).eq('emergency_id', _currentRequest!.id);



    _showCompletionDialog(summary);
  }

  void _showCompletionDialog(TripSummary summary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF1DB954),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Trip Completed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Distance Covered',
                '${summary.distanceCovered.toStringAsFixed(1)} km'),
            const Divider(),
            _buildSummaryRow('Time Taken', '${summary.timeTaken} minutes'),
            const Divider(),
            _buildSummaryRow('Emergency Type', summary.emergencyType),
            const Divider(),
            _buildSummaryRow('Patient Priority', summary.patientPriority),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentState = DriverState.idle;
                  _currentRequest = null;
                  _tripStartTime = null;
                  _currentRoutePoints = [];
                  
                  _initializeIdleState();
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'BACK TO DUTY',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF263238),
            ),
          ),
        ],
      ),
    );
  }

  void _animateCameraToShowRoute(LatLng start, LatLng end) {
    final centerLat = (start.latitude + end.latitude) / 2;
    final centerLng = (start.longitude + end.longitude) / 2;
    _mapController.move(LatLng(centerLat, centerLng), 12.5);
  }

  void _recenterToAmbulance() {
  setState(() {
    _isFollowingAmbulance = true;
  });

  try {
    final currentZoom = _mapController.camera.zoom;
    _animatedMove(_ambulanceLocation!, currentZoom);
  } catch (_) {
    _animatedMove(_ambulanceLocation!, 16.0);
  }
}


  void _fitRouteToView() {
    if (_currentRoutePoints.isEmpty) return;
    
    double minLat = _currentRoutePoints[0].latitude;
    double maxLat = _currentRoutePoints[0].latitude;
    double minLng = _currentRoutePoints[0].longitude;
    double maxLng = _currentRoutePoints[0].longitude;
    
    for (final point in _currentRoutePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    
    _mapController.move(LatLng(centerLat, centerLng), 12.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            _buildDriverHeader(),
            _buildFloatingNavPill(), // ✅ ADD HERE
            if (_showTrafficBanner) _buildTrafficBanner(),
            
            
           
            _buildBottomCard(),
            if (_currentState == DriverState.navigatingToPickup ||
                _currentState == DriverState.navigatingToHospital)
              _buildMapControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
     // 🔒 SAFETY: wait until GPS is available
  if (_ambulanceLocation == null) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _ambulanceLocation!,

        initialZoom: 13.0,
        minZoom: 5.0,
        maxZoom: 18.0,
        onPositionChanged: (position, hasGesture) {
  if (hasGesture) {
    setState(() {
      _isFollowingAmbulance = false;
    });
  }
},

      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ambulance.driver',
        ),
        PolylineLayer(
          polylines: _polylines,
        ),
        MarkerLayer(
          markers: _markers,
        ),
      ],
    );
  }

  Widget _buildTrafficBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFB8C00),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.traffic, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Traffic detected — Adjusting ETA…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

 
 

  Widget _buildMapControls() {
    return Positioned(
      bottom: 180,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'recenter',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _recenterToAmbulance,
            child: const Icon(Icons.my_location, color: Color(0xFF1DB954)),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'fit',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _fitRouteToView,
            child: const Icon(Icons.fit_screen, color: Color(0xFF1DB954)),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverHeader() {
    String statusText;
    Color statusColor;

    switch (_currentState) {
  case DriverState.idle:
    statusText = 'ON DUTY';
    statusColor = const Color(0xFF1DB954);
    break;

  case DriverState.incomingRequest:
    statusText = 'NEW REQUEST';
    statusColor = const Color(0xFFFB8C00);
    break;

  case DriverState.navigatingToPickup:
    statusText = 'BUSY';
    statusColor = const Color(0xFF1DB954);
    break;

  case DriverState.waitingForHospital: // ✅ ADD
    statusText = 'WAITING';
    statusColor = const Color(0xFFFB8C00);
    break;

  case DriverState.navigatingToHospital:
    statusText = 'TRANSPORTING';
    statusColor = const Color(0xFF0F7A3D);
    break;

  case DriverState.completed:
    statusText = 'COMPLETED';
    statusColor = const Color(0xFF1DB954);
    break;
}

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.profile.ambulanceId} • ${widget.profile.typeLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: statusColor.withOpacity(0.1),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: statusColor.withOpacity(0.3),
width: 1,
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 8,
height: 8,
decoration: BoxDecoration(
color: statusColor,
shape: BoxShape.circle,
),
),
const SizedBox(width: 6),
Text(
statusText,
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: statusColor,
letterSpacing: 0.5,
),
),
],
),
),
],
),

],
),
),
),
);
}

Widget _buildFloatingNavPill() {
  if (_currentState != DriverState.navigatingToPickup &&
      _currentState != DriverState.navigatingToHospital) {
    return const SizedBox.shrink();
  }
 if (_currentState != DriverState.navigatingToPickup &&
    _currentState != DriverState.navigatingToHospital) {
  return const SizedBox.shrink();
}

if (_remainingEta <= 0) {
  return const SizedBox.shrink();
}



  final isPickup = _currentState == DriverState.navigatingToPickup;
  final title = isPickup ? 'To Patient' : 'To Hospital';

  return Positioned(
    top: _showTrafficBanner ? 130 : 90,
    left: 16,
    right: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title • $_remainingEta min • ${_remainingDistance.toStringAsFixed(1)} km',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}


Widget _buildBottomCard() {
  return Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ✅ SINGLE SOURCE OF TRUTH FOR COLLAPSE
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isBottomCardExpanded = !_isBottomCardExpanded;
                });
              },
              child: Container(
                width: 44,
                height: 6,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // ✅ CONTENT
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isBottomCardExpanded
                  ? _buildCardForCurrentState()
                  : const SizedBox(height: 24),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildCardForCurrentState() {
switch (_currentState) {
  case DriverState.waitingForHospital:
  return _buildWaitingCard();

case DriverState.idle:
return _buildIdleCard();
case DriverState.incomingRequest:
return _buildIncomingRequestCard();
case DriverState.navigatingToPickup:
return _buildNavigatingCard(isToPickup: true);
case DriverState.navigatingToHospital:
return _buildNavigatingCard(isToPickup: false);
case DriverState.completed:
return const SizedBox.shrink();
}

}

Widget _buildWaitingCard() {
  return Container(
    margin: const EdgeInsets.all(16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: const [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Waiting for hospital confirmation…',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildIdleCard() {
return Container(
key: const ValueKey('idle'),
margin: const EdgeInsets.all(16),
child: Card(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.local_hospital_outlined,
size: 48,
color: Colors.grey[400],
),
const SizedBox(height: 16),
Text(
'Waiting for emergency request...',
style: TextStyle(
fontSize: 16,
color: Colors.grey[600],
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 8),
Text(
'Stay alert and ready to respond',

style: TextStyle(
fontSize: 14,
color: Colors.grey[500],
),
),
const SizedBox(height: 16),

],
),
),
),
);
}
Widget _buildIncomingRequestCard() {
if (_currentRequest == null) return const SizedBox.shrink();
Color priorityColor;
String priorityLabel;
switch (_currentRequest!.priority) {
  case PatientPriority.critical:
    priorityColor = const Color(0xFFE53935);
    priorityLabel = 'CRITICAL';
    break;
  case PatientPriority.high:
    priorityColor = const Color(0xFFFB8C00);
    priorityLabel = 'HIGH';
    break;
  case PatientPriority.medium:
    priorityColor = const Color(0xFFFFA726);
    priorityLabel = 'MEDIUM';
    break;
  case PatientPriority.low:
    priorityColor = const Color(0xFF66BB6A);
    priorityLabel = 'LOW';
    break;
}

return Container(
  key: const ValueKey('request'),
  margin: const EdgeInsets.all(16),
  child: Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: priorityColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: priorityColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      priorityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: priorityColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emergency,
                      size: 14,
                      color: Color(0xFFE53935),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentRequest!.emergencyType,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFB8C00).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monitor_heart,
                  color: Color(0xFFFB8C00),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Status',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentRequest!.patientStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF263238),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFFE53935),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentRequest!.pickupAddress,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentRequest!.pickupLandmark,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_hospital,
                  color: Color(0xFF1976D2),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Hospital',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentRequest!.hospitalName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.orange.withOpacity(0.2),
    borderRadius: BorderRadius.circular(12),
  ),
  child: const Text(
    'AWAITING AI',
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFFFB8C00),
      letterSpacing: 0.5,
    ),
  ),
),

              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  Icons.social_distance,
                  '${_remainingDistance.toStringAsFixed(1)} km',
                  'Distance',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  Icons.access_time,
                  '$_remainingEta min',
                  'ETA',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _rejectRequest,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'REJECT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _acceptRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ACCEPT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
}
Widget _buildNavigatingCard({required bool isToPickup}) {
if (_currentRequest == null) return const SizedBox.shrink();
final destination = isToPickup ? _currentRequest!.pickupAddress : _currentRequest!.hospitalName;
final icon = isToPickup ? Icons.location_on : Icons.local_hospital;
final color = isToPickup ? const Color(0xFFE53935) : const Color(0xFF1976D2);

return Container(
  key: ValueKey(isToPickup ? 'pickup' : 'hospital'),
  margin: const EdgeInsets.all(16),
  child: Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToPickup ? 'En Route to Patient' : 'Transporting Patient',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF263238),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
         
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isToPickup ? _arrivedAtPickup : _arrivedAtHospital,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isToPickup ? 'ARRIVED AT PICKUP' : 'ARRIVED AT HOSPITAL',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}
Widget _buildInfoChip(IconData icon, String value, String label) {
return Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: const Color(0xFFF5F7F6),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Colors.grey.withOpacity(0.1),
width: 1,
),
),
child: Column(
children: [
Icon(icon, size: 20, color: const Color(0xFF607D8B)),
const SizedBox(height: 6),
Text(
value,
style: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
color: Color(0xFF263238),
),
),
const SizedBox(height: 2),
Text(
label,
style: TextStyle(
fontSize: 12,
color: Colors.grey[600],
),
),
],
),
);
}
}
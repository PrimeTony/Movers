import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; 
import 'dart:convert';

// --- UTILITY FUNCTIONS & SERVICES ---

// Utility function to decode the polyline string returned by OSRM
List<LatLng> decodePolyline(String encoded) {
  List<LatLng> points = [];
  int index = 0;
  int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

// Nominatim Geocoding Service (Address to LatLng)
class NominatimService {
  static Future<LatLng?> geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    
    final uri = Uri.https('nominatim.openstreetmap.org', 'search', {
      'q': address,
      'format': 'json',
      'limit': '1',
      'addressdetails': '0',
    });

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'CourierApp/1.0 (movers@example.com)',
      });

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = results.first;
          final lat = double.tryParse(result['lat']);
          final lon = double.tryParse(result['lon']);
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      print('Geocoding Error: $e');
    }
    return null;
  }
}

// OSRM Routing Service (LatLng to Road Distance & Polyline)
class OsrmService {
  static Future<Map<String, dynamic>?> getRouteData(LatLng start, LatLng end) async {
    final coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    
    // Public OSRM server for demonstration
    final uri = Uri.https('router.project-osrm.org', '/route/v1/driving/$coordinates', {
      'overview': 'full',
      'geometries': 'polyline',
    });

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          // Distance is in meters, convert to km
          final distanceKm = (route['distance'] as double) / 1000.0; 
          final polyline = route['geometry'] as String;
          
          return {
            'distance': distanceKm,
            'polyline': polyline,
          };
        }
      }
    } catch (e) {
      print('OSRM Routing Error: $e');
    }
    return null;
  }
}

// --- MOCK FIREBASE SERVICE ---
class MockAuthService {
  Future<void> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    print("Mock Sign In Successful for $email");
  }
  Future<void> register(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    print("Mock Registration Successful for $email");
  }
}

final MockAuthService _auth = MockAuthService();

// --- MAIN APPLICATION ---
void main() {
  runApp(const CourierApp());
}

class CourierApp extends StatelessWidget {
  const CourierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courier Guy App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.blueAccent),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const AuthScreen(isLogin: true),
        '/register': (context) => const AuthScreen(isLogin: false),
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

// --- 1. AUTHENTICATION SCREENS (Login/Register) ---
class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitAuth() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isLogin) {
        await _auth.signIn(_emailController.text, _passwordController.text);
      } else {
        await _auth.register(_emailController.text, _passwordController.text);
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    } catch (e) {
      print('Authentication Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isLogin ? 'Courier Login' : 'Register Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.isLogin ? 'Welcome Back!' : 'Join the Service',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitAuth,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(widget.isLogin ? 'LOGIN' : 'REGISTER'),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    widget.isLogin ? '/register' : '/login',
                  );
                },
                child: Text(
                  widget.isLogin
                      ? 'Need an account? Register'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. WELCOME PAGE ---
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.delivery_dining, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text(
              'Your Deliveries, Simplified.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('Start Booking'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. HOME PAGE (State Manager for Map/Form) ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? _pickupCoords;
  LatLng? _dropoffCoords;
  List<LatLng> _routePoints = [];
  double _estimatedDistanceKm = 0.0;
  double _estimatedBaseCost = 0.0;

  // Callback function passed to RequestTruckForm to update map data
  void updateRouteData({
    required LatLng? pickup,
    required LatLng? dropoff,
    required List<LatLng> route,
    required double distance,
    required double cost,
  }) {
    setState(() {
      _pickupCoords = pickup;
      _dropoffCoords = dropoff;
      _routePoints = route;
      _estimatedDistanceKm = distance;
      _estimatedBaseCost = cost;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Truck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement Firebase logout logic
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: RequestTruckForm(
              onRouteCalculated: updateRouteData,
              initialDistance: _estimatedDistanceKm,
              initialCost: _estimatedBaseCost,
            ),
          ),
          Expanded(
            child: MapWidget(
              pickup: _pickupCoords,
              dropoff: _dropoffCoords,
              routePoints: _routePoints,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. MAP WIDGET (Using Flutter Map / OpenStreetMap) ---
class MapWidget extends StatefulWidget {
  final LatLng? pickup;
  final LatLng? dropoff;
  final List<LatLng> routePoints;

  const MapWidget({
    super.key,
    this.pickup,
    this.dropoff,
    this.routePoints = const [],
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController(); 
  LatLng? _currentLocation; 
  
  // Example: Pretoria, South Africa
  static final LatLng _kInitialPosition = LatLng(-25.747868, 28.229271); 
  static const double _kInitialZoom = 14.0;
  
  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }
    
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
    
    final newLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentLocation = newLocation;
    });

    // Move the map camera to the user's location
    _mapController.move(newLocation, _kInitialZoom);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Setup Markers
    final List<Marker> markers = [];
    
    // Current Location Marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: _currentLocation!,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
        ),
      );
    }
    
    // Pickup Marker (Green)
    if (widget.pickup != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: widget.pickup!,
          child: const Icon(Icons.flag, color: Colors.green, size: 30),
        ),
      );
    }
    
    // Dropoff Marker (Red)
    if (widget.dropoff != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: widget.dropoff!,
          child: const Icon(Icons.pin_drop, color: Colors.red, size: 30),
        ),
      );
    }

    // 2. Define Polylines
    final List<Polyline> polylines = [
      if (widget.routePoints.isNotEmpty)
        Polyline(
          points: widget.routePoints,
          color: Colors.red,
          strokeWidth: 5.0,
        ),
    ];

    return FlutterMap(
      mapController: _mapController, 
      options: MapOptions(
        initialCenter: _kInitialPosition,
        initialZoom: _kInitialZoom,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.movers', 
        ),
        // Add the Polyline Layer
        PolylineLayer(polylines: polylines), 
        // Add the Marker Layer
        MarkerLayer(markers: markers),
      ],
    );
  }
}

// --- 5. REQUEST TRUCK FORM (Performs Geocoding and Routing) ---

typedef RouteCalculatedCallback = void Function({
  required LatLng? pickup,
  required LatLng? dropoff,
  required List<LatLng> route,
  required double distance,
  required double cost,
});

class RequestTruckForm extends StatefulWidget {
  final RouteCalculatedCallback onRouteCalculated;
  final double initialDistance;
  final double initialCost;

  const RequestTruckForm({
    super.key,
    required this.onRouteCalculated,
    required this.initialDistance,
    required this.initialCost,
  });

  @override
  State<RequestTruckForm> createState() => _RequestTruckFormState();
}

class _RequestTruckFormState extends State<RequestTruckForm> {
  final _formKey = GlobalKey<FormState>();
  String _pickupLocation = '';
  String _dropoffLocation = '';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  void _handleRoutingFailure(LatLng? pickup, LatLng? dropoff) {
    // If routing fails, calculate straight-line distance as a fallback
    double distance = 0.0;
    if (pickup != null && dropoff != null) {
      distance = const Distance().as(LengthUnit.Kilometer, pickup, dropoff);
    }
    
    widget.onRouteCalculated(
        pickup: pickup,
        dropoff: dropoff,
        route: [],
        distance: distance,
        cost: distance * 15.0,
    );
  }

  // Function to calculate distance and fetch route
  Future<void> _calculateEstimate() async {
    if (_pickupLocation.isEmpty || _dropoffLocation.isEmpty) {
        // Clear estimates if fields are empty
        widget.onRouteCalculated(pickup: null, dropoff: null, route: [], distance: 0.0, cost: 0.0);
        return;
    }
    
    // 1. Geocode addresses
    final pickupCoords = await NominatimService.geocodeAddress(_pickupLocation);
    final dropoffCoords = await NominatimService.geocodeAddress(_dropoffLocation);

    if (pickupCoords != null && dropoffCoords != null) {
        // 2. Get route data from OSRM
        final routeData = await OsrmService.getRouteData(pickupCoords, dropoffCoords);

        if (routeData != null) {
          // 3. Decode polyline and calculate cost
          final distance = routeData['distance'] as double;
          final encodedPolyline = routeData['polyline'] as String;
          
          final route = decodePolyline(encodedPolyline);
          final mockBaseCost = distance * 15.0; // R15 per km base rate

          // 4. Update the parent widget's state with accurate data
          widget.onRouteCalculated(
            pickup: pickupCoords,
            dropoff: dropoffCoords,
            route: route,
            distance: distance,
            cost: mockBaseCost,
          );
        } else {
          // Handle OSRM failure
          _handleRoutingFailure(pickupCoords, dropoffCoords);
        }
    } else {
        // Handle Geocoding failure
        _handleRoutingFailure(null, null);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // TODO: 6. Implement booking logic and save to Firebase Firestore
      print('Booking Submitted:');
      print('Pickup: $_pickupLocation, Dropoff: $_dropoffLocation');
      print('Date: $_selectedDate, Time: $_selectedTime');
      print('Est. Cost: R${widget.initialCost}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Current Location Input
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Current Pickup Location (e.g., 123 Main St, City)',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Please enter pickup location' : null,
            onChanged: (value) {
              _pickupLocation = value;
              _calculateEstimate(); 
            },
          ),
          const SizedBox(height: 12),

          // Drop-off Location Input
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Drop-off Location (e.g., 456 Oak Ave, Town)',
              prefixIcon: Icon(Icons.near_me),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Please enter drop-off location' : null,
            onChanged: (value) {
              _dropoffLocation = value;
              _calculateEstimate(); 
            },
          ),
          const SizedBox(height: 12),

          // Date and Time Pickers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Select Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Select Time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      _selectedTime == null ? 'Time' : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estimated Cost Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Distance:', style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  '${widget.initialDistance.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('Base Est. Price:', style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  'R${widget.initialCost.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '* Final price will be adjusted based on cargo weight/size.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Request Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitRequest,
              icon: const Icon(Icons.local_shipping),
              label: const Text('REQUEST TRUCK'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
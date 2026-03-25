import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'theme/app_theme.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  bool _isBookingRide = false;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-6.7924, 39.2083), // Dar es Salaam coordinates
    zoom: 14.4746,
  );

  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    setState(() {
      _markers.add(
        const Marker(
          markerId: MarkerId('pickup'),
          position: LatLng(-6.7924, 39.2083),
          infoWindow: InfoWindow(title: 'Pick-up Point'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12151B) : const Color(0xFFF2F5F8),
      extendBodyBehindAppBar: _isBookingRide,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _isBookingRide ? Colors.transparent : Colors.transparent,
        titleSpacing: 16,
        leading: _isBookingRide 
          ? Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black54 : Colors.white70,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() => _isBookingRide = false),
              ),
            )
          : null,
        title: _isBookingRide ? null : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Huruchati Transport',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Find your way around the city',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _isBookingRide ? _buildRideBookingUI(isDark) : _buildMainTransportUI(isDark),
    );
  }

  Widget _buildMainTransportUI(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernQuickAction(isDark),
          const SizedBox(height: 24),
          _buildSectionTitle('Popular Services', isDark),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildServiceCard('Ride Hailing', Icons.local_taxi_rounded, Colors.orange, isDark),
              _buildServiceCard('Car Rental', Icons.directions_car_rounded, Colors.blue, isDark),
              _buildServiceCard('Bike Rental', Icons.pedal_bike_rounded, Colors.green, isDark),
              _buildServiceCard('Delivery', Icons.local_shipping_rounded, Colors.redAccent, isDark),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Recent Locations', isDark),
          const SizedBox(height: 12),
          _buildRecentLocationTile('Work', '123 Business Avenue, City Center', isDark),
          _buildRecentLocationTile('Home', '45 Garden Street, Suburbs', isDark),
          _buildRecentLocationTile('Shopping Mall', 'Grand Plaza, North Road', isDark),
        ],
      ),
    );
  }

  Widget _buildModernQuickAction(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _isBookingRide = true),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF497A72), Color(0xFF3D645D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF497A72).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where to?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Book a ride in seconds',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideBookingUI(bool isDark) {
    return Stack(
      children: [
        // Real Google Map
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: _initialPosition,
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
          style: isDark ? _darkMapStyle : null,
        ),

        // Draggable Bottom Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle for dragging
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),

                  const Text(
                    'Plan your trip',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),

                  _buildLocationInput(Icons.circle_outlined, 'Pick-up point', 'Your current location', isDark),
                  const Padding(
                    padding: EdgeInsets.only(left: 30),
                    child: SizedBox(height: 10, child: VerticalDivider(thickness: 1, color: Colors.grey)),
                  ),
                  _buildLocationInput(Icons.location_on_rounded, 'Destination', 'Grand Plaza, North Road', isDark, isPrimary: true),
                  
                  const SizedBox(height: 24),
                  const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildVehicleOption('Economy', 'Tsh 5,000', Icons.car_repair_rounded, true, isDark),
                        _buildVehicleOption('Premium', 'Tsh 12,000', Icons.directions_car_rounded, false, isDark),
                        _buildVehicleOption('XL', 'Tsh 18,000', Icons.airport_shuttle_rounded, false, isDark),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Payment Method', isDark),
                  const SizedBox(height: 12),
                  _buildRecentLocationTile('Visa •••• 4242', 'Primary payment method', isDark),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _showBookingSuccess(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm Ride',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationInput(IconData icon, String label, String hint, bool isDark, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12151B) : const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: isPrimary ? AppTheme.primaryColor : Colors.grey, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(hint, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleOption(String name, String price, IconData icon, bool isSelected, bool isDark) {
    final primary = AppTheme.primaryColor;
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isSelected 
          ? primary.withValues(alpha: 0.1) 
          : (isDark ? const Color(0xFF12151B) : const Color(0xFFF2F5F8)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? primary : Colors.transparent, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? primary : Colors.grey, size: 32),
          const SizedBox(height: 4),
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
          Text(price, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRecentLocationTile(String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.history_rounded, color: Colors.grey, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        onTap: () {},
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  void _showBookingSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ride Booked!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Your driver is on the way and will arrive in 5 minutes.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isBookingRide = false);
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  final String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#bdbdbd"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#181818"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1b1b1b"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2c2c2c"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8a8a8a"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#373737"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3c3c3c"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#4e4e4e"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3d3d3d"
      }
    ]
  }
]
''';
}

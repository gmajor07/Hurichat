import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ManageSellerAccountScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? userData;

  const ManageSellerAccountScreen({
    super.key,
    required this.userId,
    this.userData,
  });

  @override
  State<ManageSellerAccountScreen> createState() =>
      _ManageSellerAccountScreenState();
}

class _ManageSellerAccountScreenState extends State<ManageSellerAccountScreen> {
  bool _loading = false;
  bool _isActive = false;
  final Map<String, bool> _services = {
    "transport": false,
    "shopping": false,
    "food": false,
  };

  Map<String, Map<String, dynamic>> _businesses = {};
  final Map<String, File?> _businessImages = {
    "food": null,
    "shopping": null,
    "transport": null,
  };
  final Map<String, String?> _existingImageUrls = {
    "food": null,
    "shopping": null,
    "transport": null,
  };

  final Map<String, Map<String, TextEditingController>> _businessControllers = {
    "food": {
      "name": TextEditingController(),
      "location": TextEditingController(),
      "phone": TextEditingController(),
      "description": TextEditingController(),
    },
    "transport": {
      "vehicleType": TextEditingController(),
      "brand": TextEditingController(),
      "model": TextEditingController(),
      "registrationNumber": TextEditingController(),
      "color": TextEditingController(),
    },
    "shopping": {
      "shopName": TextEditingController(),
      "location": TextEditingController(),
      "phone": TextEditingController(),
      "description": TextEditingController(),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load user status and services
    _isActive = widget.userData?['sellerStatus'] == 'active';
    final List<dynamic> currentServices = widget.userData?['services'] ?? [];
    for (final service in currentServices) {
      if (_services.containsKey(service)) {
        _services[service.toString()] = true;
      }
    }

    // Load existing businesses
    await _loadBusinesses();

    setState(() => _loading = false);
  }

  Future<void> _loadBusinesses() async {
    for (final service in _services.keys) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc('${widget.userId}_$service')
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          _businesses[service] = data;

          // Load existing image URL
          _existingImageUrls[service] = data['imageUrl'];

          // Populate controllers with existing data
          final controllers = _businessControllers[service]!;
          if (service == 'food') {
            controllers['name']!.text = data['name'] ?? '';
            controllers['location']!.text = data['location'] ?? '';
            controllers['phone']!.text = data['phone'] ?? '';
            controllers['description']!.text = data['description'] ?? '';
          } else if (service == 'shopping') {
            controllers['shopName']!.text = data['shopName'] ?? '';
            controllers['location']!.text = data['location'] ?? '';
            controllers['phone']!.text = data['phone'] ?? '';
            controllers['description']!.text = data['description'] ?? '';
          } else if (service == 'transport') {
            controllers['vehicleType']!.text = data['vehicleType'] ?? '';
            controllers['brand']!.text = data['brand'] ?? '';
            controllers['model']!.text = data['model'] ?? '';
            controllers['registrationNumber']!.text =
                data['registrationNumber'] ?? '';
            controllers['color']!.text = data['color'] ?? '';
          }
        }
      } catch (e) {
        debugPrint('Error loading business for $service: $e');
      }
    }
  }

  List<String> get _selectedServices =>
      _services.entries.where((e) => e.value).map((e) => e.key).toList();

  Future<void> _pickImage(String service) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _businessImages[service] = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String service) async {
    final image = _businessImages[service];
    if (image == null) {
      // Return existing URL if no new image selected
      return _existingImageUrls[service];
    }

    try {
      final ref = FirebaseStorage.instance.ref(
        'businesses/${widget.userId}/$service/image.jpg',
      );
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return _existingImageUrls[service]; // Return existing URL on error
    }
  }

  Future<void> _saveChanges() async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service')),
      );
      return;
    }

    // Validate business forms
    if (!_validateBusinessForms()) return;

    setState(() => _loading = true);

    try {
      final primarySellerType = _selectedServices.first;

      // Update user data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'sellerStatus': _isActive ? 'active' : 'inactive',
            'services': _selectedServices,
            'sellerType': primarySellerType,
          });

      // Update/Create businesses for selected services
      for (final service in _selectedServices) {
        final businessData = _buildBusinessData(service);
        if (businessData.isNotEmpty) {
          // Upload image if changed
          final imageUrl = await _uploadImage(service);

          await FirebaseFirestore.instance
              .collection('businesses')
              .doc('${widget.userId}_$service')
              .set({
                ...businessData,
                'userId': widget.userId,
                'serviceType': service,
                if (imageUrl != null) 'imageUrl': imageUrl,
                'updatedAt': FieldValue.serverTimestamp(),
                if (!_businesses.containsKey(service))
                  'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      }

      // Delete businesses for unselected services
      for (final service in _services.keys) {
        if (!_selectedServices.contains(service) &&
            _businesses.containsKey(service)) {
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc('${widget.userId}_$service')
              .delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seller account updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }

    setState(() => _loading = false);
  }

  Map<String, dynamic> _buildBusinessData(String service) {
    final controllers = _businessControllers[service]!;

    if (service == 'food') {
      return {
        'name': controllers['name']!.text.trim(),
        'location': controllers['location']!.text.trim(),
        'phone': controllers['phone']!.text.trim(),
        'description': controllers['description']!.text.trim(),
      };
    } else if (service == 'shopping') {
      return {
        'shopName': controllers['shopName']!.text.trim(),
        'location': controllers['location']!.text.trim(),
        'phone': controllers['phone']!.text.trim(),
        'description': controllers['description']!.text.trim(),
      };
    } else if (service == 'transport') {
      return {
        'vehicleType': controllers['vehicleType']!.text.trim(),
        'brand': controllers['brand']!.text.trim(),
        'model': controllers['model']!.text.trim(),
        'registrationNumber': controllers['registrationNumber']!.text.trim(),
        'color': controllers['color']!.text.trim(),
      };
    }
    return {};
  }

  bool _validateBusinessForms() {
    for (final service in _selectedServices) {
      final controllers = _businessControllers[service]!;
      if (service == 'food') {
        if (controllers['name']!.text.isEmpty ||
            controllers['location']!.text.isEmpty ||
            controllers['phone']!.text.isEmpty) {
          _showError('Please fill in all required fields for Food service');
          return false;
        }
      } else if (service == 'shopping') {
        if (controllers['shopName']!.text.isEmpty ||
            controllers['location']!.text.isEmpty ||
            controllers['phone']!.text.isEmpty) {
          _showError('Please fill in all required fields for Shopping service');
          return false;
        }
      } else if (service == 'transport') {
        if (controllers['vehicleType']!.text.isEmpty ||
            controllers['brand']!.text.isEmpty ||
            controllers['model']!.text.isEmpty ||
            controllers['registrationNumber']!.text.isEmpty ||
            controllers['color']!.text.isEmpty) {
          _showError(
            'Please fill in all vehicle details for Transport service',
          );
          return false;
        }
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final controllers in _businessControllers.values) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Seller Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Status Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: Text(_isActive ? 'Active' : 'Inactive'),
                            subtitle: Text(
                              _isActive
                                  ? 'Your products are visible to customers'
                                  : 'Your products are hidden from customers',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Services Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Services',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select the services you offer:',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ..._services.keys.map((service) {
                            return CheckboxListTile(
                              title: Text(
                                service[0].toUpperCase() + service.substring(1),
                                style: const TextStyle(fontSize: 16),
                              ),
                              value: _services[service],
                              onChanged: (value) {
                                setState(() {
                                  _services[service] = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Business Registration Section
                  if (_selectedServices.isNotEmpty) ...[
                    const Text(
                      'Business Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Update your business information for each service:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ..._selectedServices.map((service) {
                      return _buildBusinessForm(service);
                    }).toList(),
                  ],

                  const SizedBox(height: 30),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAFAB),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBusinessForm(String service) {
    final controllers = _businessControllers[service]!;

    if (service == 'food') {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🍽️ Restaurant/Mgahawa Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Image Picker
              GestureDetector(
                onTap: () => _pickImage('food'),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _businessImages['food'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _businessImages['food']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : _existingImageUrls['food'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _existingImageUrls['food']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder('restaurant');
                            },
                          ),
                        )
                      : _buildImagePlaceholder('restaurant'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['name'],
                decoration: InputDecoration(
                  labelText: 'Restaurant Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.restaurant),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['location'],
                decoration: InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['phone'],
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['description'],
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (service == 'shopping') {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏪 Shop Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Image Picker
              GestureDetector(
                onTap: () => _pickImage('shopping'),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _businessImages['shopping'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _businessImages['shopping']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : _existingImageUrls['shopping'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _existingImageUrls['shopping']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder('shop');
                            },
                          ),
                        )
                      : _buildImagePlaceholder('shop'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['shopName'],
                decoration: InputDecoration(
                  labelText: 'Shop Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.storefront),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['location'],
                decoration: InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['phone'],
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['description'],
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (service == 'transport') {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🚗 Vehicle Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Image Picker
              GestureDetector(
                onTap: () => _pickImage('transport'),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _businessImages['transport'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _businessImages['transport']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : _existingImageUrls['transport'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _existingImageUrls['transport']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder('vehicle');
                            },
                          ),
                        )
                      : _buildImagePlaceholder('vehicle'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['vehicleType'],
                decoration: InputDecoration(
                  labelText: 'Vehicle Type (Car, Bus, Motorcycle, etc.) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.directions_car),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['brand'],
                decoration: InputDecoration(
                  labelText: 'Brand (Toyota, Nissan, etc.) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.local_offer),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['model'],
                decoration: InputDecoration(
                  labelText: 'Model *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.info),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['registrationNumber'],
                decoration: InputDecoration(
                  labelText: 'Registration Number *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers['color'],
                decoration: InputDecoration(
                  labelText: 'Color *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.palette),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildImagePlaceholder(String type) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text(
          'Tap to add $type image',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

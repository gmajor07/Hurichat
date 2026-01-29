import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class BecomeSellerPage extends StatefulWidget {
  const BecomeSellerPage({super.key});

  @override
  State<BecomeSellerPage> createState() => _BecomeSellerPageState();
}

class _BecomeSellerPageState extends State<BecomeSellerPage> {
  bool _loading = false;
  int _currentStep = 0; // 0: Select services, 1: Register businesses

  // Available services
  final Map<String, bool> services = {
    "transport": false,
    "shopping": false,
    "food": false,
  };

  // Image storage for each business
  final Map<String, File?> _businessImages = {
    "food": null,
    "shopping": null,
    "transport": null,
  };

  // Business registration form controllers
  final Map<String, Map<String, TextEditingController>> _businessControllers = {
    "food": {
      "name": TextEditingController(),
      "location": TextEditingController(),
      "phone": TextEditingController(),
      "description": TextEditingController(),
    },
    "transport": {
      "vehicleType": TextEditingController(), // Car, Bus, Motorcycle, etc.
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

  List<String> get selectedServices =>
      services.entries.where((e) => e.value).map((e) => e.key).toList();

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

  Future<String?> _uploadImage(String service, String uid) async {
    final image = _businessImages[service];
    if (image == null) return null;

    try {
      final ref = FirebaseStorage.instance.ref(
        'businesses/$uid/$service/image.jpg',
      );
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveSeller() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one service.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final primarySellerType = selectedServices.first;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Update user with services
      await userRef.update({
        "role": "seller",
        "services": selectedServices,
        "sellerType": primarySellerType,
        "sellerStatus": "active",
      });

      // Register each business
      for (final service in selectedServices) {
        final businessData = _buildBusinessData(service);
        if (businessData.isNotEmpty) {
          // Upload image if available
          final imageUrl = await _uploadImage(service, uid);

          await FirebaseFirestore.instance
              .collection("businesses")
              .doc("${uid}_$service")
              .set({
                ...businessData,
                "userId": uid,
                "serviceType": service,
                if (imageUrl != null) "imageUrl": imageUrl,
                "createdAt": FieldValue.serverTimestamp(),
              });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Businesses registered successfully! 🎉"),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }

    setState(() => _loading = false);
  }

  Map<String, dynamic> _buildBusinessData(String service) {
    final controllers = _businessControllers[service]!;

    if (service == "food") {
      return {
        "name": controllers["name"]!.text.trim(),
        "location": controllers["location"]!.text.trim(),
        "phone": controllers["phone"]!.text.trim(),
        "description": controllers["description"]!.text.trim(),
      };
    } else if (service == "shopping") {
      return {
        "shopName": controllers["shopName"]!.text.trim(),
        "location": controllers["location"]!.text.trim(),
        "phone": controllers["phone"]!.text.trim(),
        "description": controllers["description"]!.text.trim(),
      };
    } else if (service == "transport") {
      return {
        "vehicleType": controllers["vehicleType"]!.text.trim(),
        "brand": controllers["brand"]!.text.trim(),
        "model": controllers["model"]!.text.trim(),
        "registrationNumber": controllers["registrationNumber"]!.text.trim(),
        "color": controllers["color"]!.text.trim(),
      };
    }
    return {};
  }

  bool _validateBusinessForms() {
    for (final service in selectedServices) {
      final controllers = _businessControllers[service]!;
      if (service == "food" || service == "shopping") {
        if (controllers["name"]!.text.isEmpty ||
            controllers["location"]!.text.isEmpty ||
            controllers["phone"]!.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Please fill in all required fields for ${service}.",
              ),
            ),
          );
          return false;
        }
      } else if (service == "transport") {
        if (controllers["vehicleType"]!.text.isEmpty ||
            controllers["brand"]!.text.isEmpty ||
            controllers["model"]!.text.isEmpty ||
            controllers["registrationNumber"]!.text.isEmpty ||
            controllers["color"]!.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please fill in all vehicle details."),
            ),
          );
          return false;
        }
      }
    }
    return true;
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
      appBar: AppBar(title: const Text("Become a Seller")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _currentStep == 0
            ? _buildServiceSelection()
            : _buildBusinessRegistration(),
      ),
    );
  }

  Widget _buildServiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose Services to Offer",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        const Text(
          "Select the services that you want to offer to customers.",
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              ...services.keys.map((service) {
                return CheckboxListTile(
                  title: Text(
                    service[0].toUpperCase() + service.substring(1),
                    style: const TextStyle(fontSize: 16),
                  ),
                  subtitle: Text(_getServiceDescription(service)),
                  value: services[service],
                  onChanged: (value) {
                    setState(() {
                      services[service] = value ?? false;
                    });
                  },
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: () {
              if (selectedServices.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select at least one service."),
                  ),
                );
              } else {
                setState(() => _currentStep = 1);
              }
            },
            child: const Text("Next: Register Businesses"),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessRegistration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Register Your Businesses",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        const Text(
          "Register details for each service you selected.",
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              ...selectedServices.map((service) {
                return _buildBusinessForm(service);
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _currentStep = 0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () {
                        if (_validateBusinessForms()) {
                          _saveSeller();
                        }
                      },
                      child: const Text("Save & Become Seller"),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessForm(String service) {
    final controllers = _businessControllers[service]!;

    if (service == "food") {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🍽️ Register Your Restaurant/Mgahawa",
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
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add restaurant image',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["name"],
                decoration: InputDecoration(
                  labelText: "Restaurant Name *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.restaurant),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["location"],
                decoration: InputDecoration(
                  labelText: "Location *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["phone"],
                decoration: InputDecoration(
                  labelText: "Phone Number *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["description"],
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Description (optional)",
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
    } else if (service == "shopping") {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🏪 Register Your Shop",
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
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add shop image',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["shopName"],
                decoration: InputDecoration(
                  labelText: "Shop Name *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.storefront),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["location"],
                decoration: InputDecoration(
                  labelText: "Location *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["phone"],
                decoration: InputDecoration(
                  labelText: "Phone Number *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["description"],
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Description (optional)",
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
    } else if (service == "transport") {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🚗 Register Your Vehicle",
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
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add vehicle image',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["vehicleType"],
                decoration: InputDecoration(
                  labelText: "Vehicle Type (Car, Bus, Motorcycle, etc.) *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.directions_car),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["brand"],
                decoration: InputDecoration(
                  labelText: "Brand (Toyota, Nissan, etc.) *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.local_offer),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["model"],
                decoration: InputDecoration(
                  labelText: "Model *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.info),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["registrationNumber"],
                decoration: InputDecoration(
                  labelText: "Registration Number *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllers["color"],
                decoration: InputDecoration(
                  labelText: "Color *",
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

  String _getServiceDescription(String service) {
    switch (service) {
      case "food":
        return "Sell food, meals, and snacks";
      case "shopping":
        return "Sell products in a shop";
      case "transport":
        return "Offer transportation services";
      default:
        return "";
    }
  }
}

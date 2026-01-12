import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BecomeSellerPage extends StatefulWidget {
  const BecomeSellerPage({super.key});

  @override
  State<BecomeSellerPage> createState() => _BecomeSellerPageState();
}

class _BecomeSellerPageState extends State<BecomeSellerPage> {
  bool _loading = false;

  // Available services
  final Map<String, bool> services = {
    "transport": false,
    "shopping": false,
    "food": false,
  };

  Future<void> _saveSeller() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Collect selected services
    final selectedServices = services.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one service.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "role": "seller",
        "services": selectedServices,
        "sellerStatus": "active",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You are now a seller, services saved 🎉"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Become a Seller")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
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

            // SERVICES CHECKBOXES
            ...services.keys.map((service) {
              return CheckboxListTile(
                title: Text(
                  service[0].toUpperCase() + service.substring(1),
                  style: const TextStyle(fontSize: 16),
                ),
                value: services[service],
                onChanged: (value) {
                  setState(() {
                    services[service] = value ?? false;
                  });
                },
              );
            }).toList(),

            const SizedBox(height: 30),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveSeller,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: const Text("Save & Become Seller"),
                  ),
          ],
        ),
      ),
    );
  }
}

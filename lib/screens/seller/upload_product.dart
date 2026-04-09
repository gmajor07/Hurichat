import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Define a new data model for our category items.
class CategoryItem {
  final String name;
  final IconData icon;

  const CategoryItem(this.name, this.icon);
}

/// A Flutter screen for uploading a new product to the marketplace.
class MarketplaceUploadPage extends StatefulWidget {
  /// Constructor for the upload page.
  const MarketplaceUploadPage({super.key});

  @override
  State<MarketplaceUploadPage> createState() => _MarketplaceUploadPageState();
}

class _MarketplaceUploadPageState extends State<MarketplaceUploadPage> {
  // --- Controllers and Global Keys ---
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // --- State Variables ---
  bool _isLoading = false;
  bool _isUploadingImages = false;
  String? _sellerType;
  String? _category;
  String? _subCategory;
  String? _condition;
  String _currency = 'TSH';
  final List<String> _deliveryOptions = [];
  final List<File> _images = [];

  // --- Transport-Specific Variables ---
  String? _transmission;
  String? _fuelType;
  int? _mileage;
  int? _seatingCapacity;
  int? _yearOfManufacture;

  static const int _maxImages = 5;

  final Map<String, List<CategoryItem>> _categoryItemsMap = const {
    "shopping": [
      CategoryItem("Electronics", Icons.devices_other),
      CategoryItem("Clothing", Icons.checkroom),
      CategoryItem("Accessories", Icons.watch),
      CategoryItem("Books", Icons.book),
      CategoryItem("Shoes", Icons.local_offer),
      CategoryItem("Grocery", Icons.shopping_cart),
      CategoryItem("Kitchen", Icons.kitchen),
    ],
    "food": [
      CategoryItem("Meals", Icons.restaurant),
      CategoryItem("Snacks", Icons.cookie),
      CategoryItem("Drinks", Icons.local_drink),
    ],
    "transport": [
      CategoryItem("Car", Icons.directions_car),
      CategoryItem("Bus", Icons.directions_bus),
      CategoryItem("Taxi", Icons.local_taxi),
    ],
  };

  final Map<String, List<String>> _subCategoriesMap = const {
    "Electronics": ["Smartphone", "Laptop", "TV", "Tablet", "Headphones"],
    "Clothing": ["Men", "Women", "Kids"],
    "Accessories": ["Bags", "Watches", "Jewelry", "Belts", "Scarves"],
    "Books": ["Fiction", "Non-fiction", "Comics", "Educational"],
    "Shoes": ["Men", "Women", "Kids", "Sports"],
    "Grocery": ["Vegetables", "Fruits", "Snacks", "Beverages"],
    "Kitchen": ["Cookware", "Utensils", "Appliances", "Dining"],
    "Meals": ["Breakfast", "Lunch", "Dinner"],
    "Snacks": ["Chips", "Pastries", "Sweets"],
    "Drinks": ["Juice", "Soft Drink", "Alcohol"],
    "Car": ["Sedan", "SUV", "Pickup"],
    "Bus": ["Mini Bus", "Coach"],
    "Taxi": ["Standard", "Luxury"],
  };

  final List<String> _conditionOptions = const ["New", "Used", "Refurbished"];
  final List<String> _deliveryOptionsList = const ["Pickup", "Delivery"];
  final List<String> _transmissionOptions = const ["Manual", "Automatic"];
  final List<String> _fuelTypeOptions = const ["Petrol", "Diesel", "Electric", "Hybrid"];

  @override
  void initState() {
    super.initState();
    _checkSellerStatus();
    _fetchSellerType();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSellerStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showErrorSnackBar("User not logged in.");
        Navigator.pop(context);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists) {
        final userData = doc.data();
        if (userData?['role'] != 'seller' || userData?['sellerStatus'] != 'active') {
          _showErrorSnackBar("You must be an active seller to upload products.");
          Navigator.pop(context);
          return;
        }
      } else {
        _showErrorSnackBar("User data not found.");
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar("Failed to check seller status.");
      Navigator.pop(context);
    }
  }

  Future<void> _fetchSellerType() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists) {
        final fetchedSellerType = doc.data()?['sellerType'] as String?;
        if (mounted) {
          setState(() {
            _sellerType = fetchedSellerType ?? 'shopping';
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar("Failed to load seller type.");
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return 'Please enter the $fieldName';
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a price';
    final price = double.tryParse(value);
    if (price == null || price <= 0) return 'Price must be a valid positive number';
    return null;
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(maxWidth: 1024, maxHeight: 1024, imageQuality: 85);

      if (pickedFiles.isNotEmpty) {
        final newImages = pickedFiles.map((e) => File(e.path)).toList();
        if (_images.length + newImages.length > _maxImages) {
          _showErrorSnackBar("Maximum $_maxImages images allowed.");
          final availableSlots = _maxImages - _images.length;
          _images.addAll(newImages.take(availableSlots));
        } else {
          _images.addAll(newImages);
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      _showErrorSnackBar("Failed to pick images.");
    }
  }

  void _removeImage(int index) {
    if (mounted) setState(() => _images.removeAt(index));
  }

  Future<List<String>> _uploadImages(String productId) async {
    if (_images.isEmpty) return [];
    if (mounted) setState(() => _isUploadingImages = true);
    try {
      final List<String> urls = [];
      for (int i = 0; i < _images.length; i++) {
        final ref = FirebaseStorage.instance.ref("products/$productId/image_$i.jpg");
        await ref.putFile(_images[i]);
        urls.add(await ref.getDownloadURL());
      }
      return urls;
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _subCategory == null) {
      _showErrorSnackBar("Select category and sub-category.");
      return;
    }
    _formKey.currentState!.save();
    if (mounted) setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final productRef = FirebaseFirestore.instance.collection("products").doc();
      final imageUrls = await _uploadImages(productRef.id);
      await productRef.set({
        "productId": productRef.id,
        "name": _nameCtrl.text.trim(),
        "description": _descCtrl.text.trim(),
        "price": double.parse(_priceCtrl.text),
        "currency": _currency,
        "quantity": int.parse(_quantityCtrl.text),
        "condition": _sellerType == 'shopping' ? _condition : null,
        "category": _category,
        "subCategory": _subCategory,
        "images": imageUrls,
        "sellerId": uid,
        "sellerType": _sellerType,
        "location": _locationCtrl.text.trim(),
        "deliveryOptions": _deliveryOptions,
        "yearOfManufacture": _sellerType == 'transport' ? _yearOfManufacture : null,
        "transmission": _sellerType == 'transport' ? _transmission : null,
        "fuelType": _sellerType == 'transport' ? _fuelType : null,
        "mileage": _sellerType == 'transport' ? _mileage : null,
        "seatingCapacity": _sellerType == 'transport' ? _seatingCapacity : null,
        "status": "active",
        "createdAt": FieldValue.serverTimestamp(),
      });
      _showSuccessSnackBar("Product uploaded!");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar("Upload failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12151B) : const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: const Text("Upload Product", style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(isDark, primary),
              const SizedBox(height: 24),
              _buildSectionTitle("Product Details", isDark),
              const SizedBox(height: 12),
              _buildTextField(_nameCtrl, "Product Name", Icons.shopping_bag_outlined, isDark),
              const SizedBox(height: 16),
              _buildTextField(_descCtrl, "Description", Icons.description_outlined, isDark, maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildTextField(_priceCtrl, "Price", Icons.attach_money, isDark, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCurrencyDropdown(isDark)),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Categorization", isDark),
              const SizedBox(height: 12),
              _buildCategorySelector(isDark, primary),
              const SizedBox(height: 16),
              if (_category != null) _buildSubCategoryDropdown(isDark),
              const SizedBox(height: 24),
              _buildSectionTitle("Inventory & Location", isDark),
              const SizedBox(height: 12),
              _buildTextField(_quantityCtrl, "Quantity", Icons.inventory_2_outlined, isDark, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(_locationCtrl, "Location", Icons.location_on_outlined, isDark),
              const SizedBox(height: 32),
              _buildUploadButton(primary),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black54));
  }

  Widget _buildImagePicker(bool isDark, Color primary) {
    return Column(
      children: [
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withValues(alpha: 0.3), style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 40, color: primary),
                const SizedBox(height: 8),
                Text("Add Product Images", style: TextStyle(fontWeight: FontWeight.w600, color: primary)),
                Text("Up to 5 images", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_images[index], width: 80, height: 80, fit: BoxFit.cover)),
                    Positioned(right: 4, top: 4, child: GestureDetector(onTap: () => _removeImage(index), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5))),
      ),
      validator: (v) => _validateRequired(v, label.toLowerCase()),
    );
  }

  Widget _buildCurrencyDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _currency,
      decoration: InputDecoration(
        labelText: "Currency",
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      items: const [DropdownMenuItem(value: 'TSH', child: Text('TSH')), DropdownMenuItem(value: 'USD', child: Text('USD'))],
      onChanged: (v) => setState(() => _currency = v!),
    );
  }

  Widget _buildCategorySelector(bool isDark, Color primary) {
    return InkWell(
      onTap: () => _showCategorySelectionDialog(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E222D) : Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.category_outlined, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(child: Text(_category ?? "Select Category", style: TextStyle(fontSize: 16, color: _category == null ? Colors.grey.shade500 : (isDark ? Colors.white : Colors.black87)))),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryDropdown(bool isDark) {
    final items = _subCategoriesMap[_category!] ?? [];
    return DropdownButtonFormField<String>(
      value: _subCategory,
      decoration: InputDecoration(
        labelText: "Sub-Category",
        prefixIcon: const Icon(Icons.account_tree_outlined, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _subCategory = v),
    );
  }

  Widget _buildUploadButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProduct,
        style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Upload Product", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

  void _showCategorySelectionDialog(BuildContext context) {
    final items = _categoryItemsMap[_sellerType ?? 'shopping'] ?? [];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((item) => InkWell(
                onTap: () { Navigator.pop(context); setState(() { _category = item.name; _subCategory = null; }); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _category == item.name ? AppTheme.primaryColor : Colors.transparent)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(item.icon, size: 18, color: AppTheme.primaryColor), const SizedBox(width: 8), Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))],
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

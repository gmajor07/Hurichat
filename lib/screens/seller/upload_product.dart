import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

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
  String _currency = 'TSH'; // New: Currency selection (TSH or USD)
  final List<String> _deliveryOptions = [];
  final List<File> _images = [];

  // --- Transport-Specific Variables ---
  String? _transmission; // Manual or Automatic
  String? _fuelType; // Petrol, Diesel, Electric, Hybrid
  int? _mileage; // in kilometers
  int? _seatingCapacity;
  int? _yearOfManufacture;

  // --- Static Data Maps ---
  static const int _maxImages = 5;

  // Defines categories based on the primary seller type (e.g., 'shopping').
  // NOTE: This map now maps sellerType to a list of CategoryItem objects.
  // These category names (Electronics, Clothing, Accessories) are the primary groupings,
  // while subcategories (Men, Women, Jewelry, etc.) are the actual filters used by ShoppingScreen.
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

  // The sub-categories map still uses string keys/values.
  // NOTE: These match the subcategory chips shown in ShoppingScreen for filtering.
  // Map each category to its available subcategory options (which users see as quick-selection filters).
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

  // --- Transport-Specific Options ---
  final List<String> _transmissionOptions = const ["Manual", "Automatic"];
  final List<String> _fuelTypeOptions = const [
    "Petrol",
    "Diesel",
    "Electric",
    "Hybrid",
  ];

  // --- Lifecycle Methods ---

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

  // --- Firebase Data Fetching ---

  Future<void> _checkSellerStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showErrorSnackBar("User not logged in.");
        Navigator.pop(context);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
      if (doc.exists) {
        final userData = doc.data();
        if (userData?['role'] != 'seller' ||
            userData?['sellerStatus'] != 'active') {
          _showErrorSnackBar(
            "You must be an active seller to upload products.",
          );
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

  /// Fetches the current user's seller type from Firestore.
  Future<void> _fetchSellerType() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showErrorSnackBar("User not logged in.");
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
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

  // --- Validation Methods ---

  /// General validation for required text fields.
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the $fieldName';
    }
    return null;
  }

  /// Validation for product price.
  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a price';
    }
    final price = double.tryParse(value);
    if (price == null || price <= 0) {
      return 'Price must be a valid positive number';
    }
    if (price > 1000000) {
      return 'Price value seems excessive';
    }
    return null;
  }

  /// Validation for product quantity.
  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the quantity';
    }
    final quantity = int.tryParse(value);
    if (quantity == null || quantity <= 0) {
      return 'Quantity must be a valid positive integer';
    }
    if (quantity > 1000) {
      return 'Maximum quantity allowed is 1000';
    }
    return null;
  }

  /// Validation for dropdown fields.
  String? _validateDropdown(String? value, String fieldName) {
    if (value == null) {
      return 'Please select a $fieldName';
    }
    return null;
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final newImages = pickedFiles.map((e) => File(e.path)).toList();
        final totalImages = _images.length + newImages.length;

        if (totalImages > _maxImages) {
          _showErrorSnackBar(
            "Maximum $_maxImages images allowed. Cannot add all.",
          );
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
    if (mounted) {
      setState(() {
        _images.removeAt(index);
      });
    }
  }

  Future<List<String>> _uploadImages(String productId) async {
    if (_images.isEmpty) return [];

    if (mounted) setState(() => _isUploadingImages = true);

    try {
      final List<String> urls = [];
      for (int i = 0; i < _images.length; i++) {
        final ref = FirebaseStorage.instance.ref(
          "products/$productId/image_$i.jpg",
        );
        await ref.putFile(_images[i]);
        urls.add(await ref.getDownloadURL());
      }
      return urls;
    } catch (e) {
      rethrow;
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar("Please fix the errors above to continue.");
      return;
    }

    if (_category == null || _subCategory == null) {
      _showErrorSnackBar("Please select a category and sub-category.");
      return;
    }

    // Validate condition for shopping sellers
    if (_sellerType == 'shopping' && _condition == null) {
      _showErrorSnackBar("Please select a condition.");
      return;
    }

    // Validate transport-specific fields
    if (_sellerType == 'transport') {
      if (_yearOfManufacture == null ||
          _transmission == null ||
          _fuelType == null ||
          _mileage == null ||
          _seatingCapacity == null) {
        _showErrorSnackBar(
          "Please fill in all transport details (Year, Transmission, Fuel Type, Mileage, Seating Capacity).",
        );
        return;
      }
    }

    _formKey.currentState!.save();

    if (mounted) setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception("Authentication error: User not logged in.");
      }

      final productRef = FirebaseFirestore.instance
          .collection("products")
          .doc();

      final imageUrls = _images.isNotEmpty
          ? await _uploadImages(productRef.id)
          : <String>[];

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
        // Transport-specific fields
        "yearOfManufacture": _sellerType == 'transport'
            ? _yearOfManufacture
            : null,
        "transmission": _sellerType == 'transport' ? _transmission : null,
        "fuelType": _sellerType == 'transport' ? _fuelType : null,
        "mileage": _sellerType == 'transport' ? _mileage : null,
        "seatingCapacity": _sellerType == 'transport' ? _seatingCapacity : null,
        "status": "active",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      _showSuccessSnackBar("Product uploaded successfully!");
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar("Upload failed: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          "Selected Images (${_images.length}/$_maxImages)",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _images[index],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- NEW: Category Selection Dialog Implementation ---

  /// Displays the grid selection dialog for categories.
  void _showCategorySelectionDialog(BuildContext context) {
    if (_sellerType == null) return;

    final items = _categoryItemsMap[_sellerType!];
    if (items == null || items.isEmpty) {
      _showErrorSnackBar(
        "No categories available for seller type '$_sellerType'.",
      );
      return;
    }

    showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text("Select Product Category *"),
          contentPadding: const EdgeInsets.all(16),
          content: SizedBox(
            width: double.maxFinite,
            // GridView with 2 columns
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5, // Controls the card shape
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item.name == _category;

                return InkWell(
                  onTap: () {
                    // Return the selected category name
                    Navigator.of(dialogContext).pop(item.name);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 30,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).then((selectedCategory) {
      if (selectedCategory != null) {
        if (mounted) {
          setState(() {
            _category = selectedCategory;
            _subCategory = null; // Reset sub-category
          });
          // This ensures the form field state is updated for validation
          _formKey.currentState?.validate();
        }
      }
    });
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Upload Product")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- Seller Type Display ---
              if (_sellerType != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Seller Type: ${_sellerType![0].toUpperCase()}${_sellerType!.substring(1)}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

              // --- NEW: CATEGORY SELECTION BUTTON/TILE ---
              if (_sellerType != null)
                _buildCategorySelectionTile(context, colorScheme),

              const SizedBox(height: 16),

              // --- SUBCATEGORY SELECT (Dropdown remains) ---
              if (_category != null)
                _buildCategoryDropdown(
                  context: context,
                  label: 'Sub-Category',
                  value: _subCategory,
                  items: _subCategoriesMap[_category!]!,
                  onChanged: (val) => setState(() => _subCategory = val),
                  validator: (val) => _validateDropdown(val, 'sub-category'),
                ),

              if (_category != null) const SizedBox(height: 16),

              // --- CONDITION SELECT (Only for Shopping) ---
              if (_sellerType == 'shopping' && _category != null)
                _buildConditionDropdown(
                  context: context,
                  label: 'Condition',
                  value: _condition,
                  items: _conditionOptions,
                  onChanged: (val) => setState(() => _condition = val),
                  validator: (val) => _validateDropdown(val, 'condition'),
                ),

              if (_sellerType == 'shopping' && _category != null)
                const SizedBox(height: 16),

              // --- TRANSPORT-SPECIFIC FIELDS ---
              if (_sellerType == 'transport' && _category != null) ...[
                // Year of Manufacture
                TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _buildModernInputDecoration(
                    context: context,
                    labelText: "Year of Manufacture *",
                    icon: Icons.calendar_today_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the year of manufacture';
                    }
                    final year = int.tryParse(value);
                    if (year == null ||
                        year < 1900 ||
                        year > DateTime.now().year) {
                      return 'Please enter a valid year';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    if (value != null) _yearOfManufacture = int.parse(value);
                  },
                ),
                const SizedBox(height: 16),

                // Transmission
                DropdownButtonFormField<String>(
                  value: _transmission,
                  decoration: _buildModernInputDecoration(
                    context: context,
                    labelText: "Transmission *",
                    icon: Icons.settings,
                  ),
                  items: _transmissionOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _transmission = value);
                  },
                  validator: (val) => _validateDropdown(val, 'transmission'),
                ),
                const SizedBox(height: 16),

                // Fuel Type
                DropdownButtonFormField<String>(
                  value: _fuelType,
                  decoration: _buildModernInputDecoration(
                    context: context,
                    labelText: "Fuel Type *",
                    icon: Icons.local_gas_station,
                  ),
                  items: _fuelTypeOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _fuelType = value);
                  },
                  validator: (val) => _validateDropdown(val, 'fuel type'),
                ),
                const SizedBox(height: 16),

                // Mileage (in km)
                TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _buildModernInputDecoration(
                    context: context,
                    labelText: "Mileage *",
                    icon: Icons.speed,
                  ).copyWith(suffixText: "km"),
                  validator: (value) => _validateRequired(value, 'mileage'),
                  onSaved: (value) {
                    if (value != null) _mileage = int.parse(value);
                  },
                ),
                const SizedBox(height: 16),

                // Seating Capacity
                TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _buildModernInputDecoration(
                    context: context,
                    labelText: "Seating Capacity *",
                    icon: Icons.event_seat,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter seating capacity';
                    }
                    final capacity = int.tryParse(value);
                    if (capacity == null || capacity <= 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    if (value != null) _seatingCapacity = int.parse(value);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // --- PRODUCT NAME ---
              TextFormField(
                controller: _nameCtrl,
                decoration: _buildModernInputDecoration(
                  context: context,
                  labelText: "Product Name *",
                  icon: Icons.shopping_bag_outlined,
                ),
                validator: (value) => _validateRequired(value, 'product name'),
              ),

              const SizedBox(height: 16),

              // --- DESCRIPTION ---
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _buildModernInputDecoration(
                  context: context,
                  labelText: "Description",
                  icon: Icons.description_outlined,
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              // --- PRICE ---
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: _buildModernInputDecoration(
                  context: context,
                  labelText: "Price *",
                  icon: Icons.attach_money,
                ).copyWith(prefixText: "\$ "),
                validator: _validatePrice,
              ),

              const SizedBox(height: 16),

              // --- CURRENCY SELECTION ---
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: _buildModernInputDecoration(
                  context: context,
                  labelText: "Currency *",
                  icon: Icons.currency_exchange,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'TSH',
                    child: Text('Tanzanian Shilling (TSH)'),
                  ),
                  DropdownMenuItem(
                    value: 'USD',
                    child: Text('US Dollar (USD)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _currency = value ?? 'TSH';
                  });
                },
              ),

              const SizedBox(height: 16),

              // --- QUANTITY ---
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _buildModernInputDecoration(
                  context: context,
                  labelText: "Quantity *",
                  icon: Icons.numbers,
                ).copyWith(suffixText: "units"),
                validator: _validateQuantity,
              ),

              const SizedBox(height: 16),

              // --- LOCATION ---
              TextFormField(
                controller: _locationCtrl,
                decoration: _buildModernInputDecoration(
                  context: context,
                  labelText: "Location (optional)",
                  icon: Icons.location_on_outlined,
                ),
              ),

              const SizedBox(height: 20),

              // --- DELIVERY OPTIONS ---
              Text(
                "🚚 Delivery Options",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ..._deliveryOptionsList.map((option) {
                return CheckboxListTile(
                  title: Text(option),
                  dense: true,
                  value: _deliveryOptions.contains(option),
                  onChanged: (val) {
                    if (mounted) {
                      setState(() {
                        if (val == true) {
                          _deliveryOptions.add(option);
                        } else {
                          _deliveryOptions.remove(option);
                        }
                      });
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),

              const SizedBox(height: 20),

              // --- IMAGE UPLOAD SECTION ---
              Text(
                "📸 Product Images",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Select up to $_maxImages images (optional)",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _images.length < _maxImages ? _pickImages : null,
                    icon: const Icon(Icons.photo_library),
                    label: Text(_images.isEmpty ? "Select Images" : "Add More"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                  ),
                  if (_isUploadingImages) ...[
                    const SizedBox(width: 16),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ],
              ),

              _buildImagePreview(),

              const SizedBox(height: 30),

              // --- UPLOAD BUTTON ---
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _saveProduct,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Upload Product",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW: Category Selection Tile Widget ---
  Widget _buildCategorySelectionTile(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    // Determine the icon for the currently selected category
    IconData currentIcon = Icons.list_alt;
    final selectedItem = _categoryItemsMap[_sellerType]?.firstWhere(
      (item) => item.name == _category,
      orElse: () => const CategoryItem('', Icons.list_alt),
    );

    if (selectedItem != null && selectedItem.name.isNotEmpty) {
      currentIcon = selectedItem.icon;
    }

    return InkWell(
      onTap: () => _showCategorySelectionDialog(context),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: _category == null
              ? Border.all(
                  color: colorScheme.error,
                  width: 2,
                ) // Error border if not selected
              : null,
        ),
        child: Row(
          children: [
            Icon(currentIcon, color: colorScheme.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _category ?? "Select Category *",
                style: TextStyle(
                  fontSize: 16,
                  color: _category == null
                      ? colorScheme.error
                      : colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurface),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget for Dropdowns (Used for Sub-Category and Condition) ---

  /// Generic helper function to build a standardized DropdownButtonFormField.
  Widget _buildCategoryDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: "$label *",
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        prefixIcon: const Icon(Icons.category), // Using a generic icon here
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  /// Specialized Dropdown for Condition (Uses a different icon)
  Widget _buildConditionDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: "$label *",
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        prefixIcon: const Icon(Icons.star_rate_outlined),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  // --- Helper Method for TextFields ---

  /// Returns a standardized, modern Input Decoration for TextFields.
  InputDecoration _buildModernInputDecoration({
    required BuildContext context,
    required String labelText,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: labelText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      border: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),

      prefixIcon: Icon(icon),
    );
  }
}

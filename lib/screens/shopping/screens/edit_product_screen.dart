import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../models/firebase_product.dart';

class EditProductScreen extends StatefulWidget {
  final FirebaseProduct product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _subCategoryController;
  late TextEditingController _conditionController;
  late TextEditingController _descriptionController;
  late String _currency;
  late List<String> _existingImages;
  final List<File> _newImages = [];

  bool _loading = false;
  bool _isUploadingImages = false;

  static const int _maxImages = 5;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _priceController = TextEditingController(text: p.price.toString());
    _categoryController = TextEditingController(text: p.category);
    _subCategoryController = TextEditingController(text: p.subCategory);
    _conditionController = TextEditingController(text: p.condition);
    _descriptionController = TextEditingController(text: p.description ?? '');
    _currency = p.currency;
    _existingImages = List<String>.from(
      p.images.isNotEmpty
          ? p.images
          : (p.imageUrl.isNotEmpty ? [p.imageUrl] : <String>[]),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      final availableSlots =
          _maxImages - (_existingImages.length + _newImages.length);
      if (availableSlots <= 0) {
        _showSnackBar('Maximum $_maxImages images allowed.', Colors.red);
        return;
      }

      final selectedImages = pickedFiles
          .take(availableSlots)
          .map((file) => File(file.path))
          .toList();

      setState(() {
        _newImages.addAll(selectedImages);
      });

      if (pickedFiles.length > availableSlots) {
        _showSnackBar('Maximum $_maxImages images allowed.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Failed to pick images.', Colors.red);
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_newImages.isEmpty) return _existingImages;

    setState(() => _isUploadingImages = true);
    try {
      final List<String> uploadedUrls = List<String>.from(_existingImages);
      final startIndex = _existingImages.length;
      for (int i = 0; i < _newImages.length; i++) {
        final ref = FirebaseStorage.instance.ref(
          'products/${widget.product.id}/image_${startIndex + i}.jpg',
        );
        await ref.putFile(_newImages[i]);
        uploadedUrls.add(await ref.getDownloadURL());
      }
      return uploadedUrls;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImages = false);
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImages.isEmpty && _newImages.isEmpty) {
      _showSnackBar('Pick at least one product image.', Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      final updatedImages = await _uploadImages();
      final updatedProduct = FirebaseProduct(
        id: widget.product.id,
        name: _nameController.text.trim(),
        images: updatedImages,
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        currency: _currency,
        category: _categoryController.text.trim(),
        subCategory: _subCategoryController.text.trim(),
        condition: _conditionController.text.trim(),
        sellerId: widget.product.sellerId,
        description: _descriptionController.text.trim(),
        quantity: widget.product.quantity,
        location: widget.product.location,
        deliveryOptions: widget.product.deliveryOptions,
        sellerType: widget.product.sellerType,
        soldCount: widget.product.soldCount,
        discountPrice: widget.product.discountPrice,
        discountDescription: widget.product.discountDescription,
      );

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update(updatedProduct.toMap());

      if (mounted) {
        _showSnackBar('Product updated successfully', AppTheme.primaryColor);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to update product: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _subCategoryController.dispose();
    _conditionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon,
    bool isDark,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12151B)
          : const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: const Text(
          'Edit Product',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: _isUploadingImages ? Colors.orange : primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildImagePicker(isDark, primary),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _nameController,
                      'Product Name',
                      Icons.shopping_bag_outlined,
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            _priceController,
                            'Price',
                            Icons.attach_money,
                            isDark,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCurrencyDropdown(isDark)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _categoryController,
                      'Category',
                      Icons.category_outlined,
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _subCategoryController,
                      'Sub-category',
                      Icons.account_tree_outlined,
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _conditionController,
                      'Condition',
                      Icons.star_rate_outlined,
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _descriptionController,
                      'Description',
                      Icons.description_outlined,
                      isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _updateProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Update Product',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker(bool isDark, Color primary) {
    final totalImages = _existingImages.length + _newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: totalImages >= _maxImages ? null : _pickImages,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primary.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 40, color: primary),
                const SizedBox(height: 8),
                Text(
                  _newImages.isEmpty ? 'Pick Another Image' : 'Add More Images',
                  style: TextStyle(fontWeight: FontWeight.w600, color: primary),
                ),
                Text(
                  '$totalImages of $_maxImages selected',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
        if (_existingImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPreviewStrip(
            title: 'Current Images',
            itemCount: _existingImages.length,
            imageBuilder: (index) => Image.network(
              _existingImages[index],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImagePlaceholder(isDark),
            ),
            onRemove: _removeExistingImage,
          ),
        ],
        if (_newImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPreviewStrip(
            title: 'New Images',
            itemCount: _newImages.length,
            imageBuilder: (index) => Image.file(
              _newImages[index],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
            onRemove: _removeNewImage,
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewStrip({
    required String title,
    required int itemCount,
    required Widget Function(int index) imageBuilder,
    required void Function(int index) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageBuilder(index),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      width: 80,
      height: 80,
      color: isDark ? const Color(0xFF1E222D) : const Color(0xFFE9EEF4),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: isDark ? Colors.white54 : Colors.black38,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: _buildInputDecoration(label, icon, isDark),
      validator: (val) => val == null || val.isEmpty ? 'Enter $label' : null,
    );
  }

  Widget _buildCurrencyDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _currency,
      decoration: InputDecoration(
        labelText: "Currency",
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'TSH', child: Text('TSH')),
        DropdownMenuItem(value: 'USD', child: Text('USD')),
      ],
      onChanged: (value) {
        setState(() {
          _currency = value ?? 'TSH';
        });
      },
    );
  }
}

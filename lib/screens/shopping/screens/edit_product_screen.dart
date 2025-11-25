import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  late TextEditingController _imageUrlController;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _priceController = TextEditingController(text: p.price);
    _categoryController = TextEditingController(text: p.category);
    _subCategoryController = TextEditingController(text: p.subCategory);
    _conditionController = TextEditingController(text: p.condition);
    _descriptionController = TextEditingController(text: p.description ?? '');
    _imageUrlController = TextEditingController(text: p.imageUrl);
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final updatedProduct = FirebaseProduct(
        id: widget.product.id,
        name: _nameController.text.trim(),
        price: _priceController.text.trim(),
        category: _categoryController.text.trim(),
        subCategory: _subCategoryController.text.trim(),
        condition: _conditionController.text.trim(),
        sellerId: widget.product.sellerId,
        description: _descriptionController.text.trim(),
        // NOTE: The imageUrl here must be manually re-entered/verified by the user
        imageUrl: _imageUrlController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update(updatedProduct.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );

      // Return to the previous screen (SellerProductsScreen) and refresh
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update product: $e')));
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
    _imageUrlController.dispose();
    super.dispose();
  }

  // Helper method to apply modern input decoration
  InputDecoration _buildInputDecoration(String label) {
    // 🔑 Use the primary color for focus state
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: primaryColor,
          width: 2,
        ), // Highlight focus with primary color
      ),
      // Optional: Add a subtle fill color
      // filled: true,
      // fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔑 Access Theme Colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product'), elevation: 0),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Product Name ---
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Product Name'),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter product name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Price ---
                    TextFormField(
                      controller: _priceController,
                      decoration: _buildInputDecoration('Price'),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter price' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Category ---
                    TextFormField(
                      controller: _categoryController,
                      decoration: _buildInputDecoration('Category'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter category' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Sub-category ---
                    TextFormField(
                      controller: _subCategoryController,
                      decoration: _buildInputDecoration('Sub-category'),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter sub-category'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Condition ---
                    TextFormField(
                      controller: _conditionController,
                      decoration: _buildInputDecoration('Condition'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter condition' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Image URL ---
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: _buildInputDecoration('Image URL'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter image URL' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Description ---
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _buildInputDecoration('Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 30),

                    // --- Update Button (Styled) ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _updateProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor, // Themed background
                          foregroundColor: Colors.white, // White text
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              10,
                            ), // Rounded corners
                          ),
                          elevation: 4, // Subtle shadow
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Update Product',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
}

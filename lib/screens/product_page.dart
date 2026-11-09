// Preserved from In-Class 12 (Part 1) Product Manager.
// Uses the existing Cloud Firestore 'products' collection.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Accept ordinary nonnegative decimal amounts. Reject currency symbols,
// commas, negative numbers, NaN, Infinity, and overflowing values.
double? parseProductPrice(String input) {
  final text = input.trim();
  if (!RegExp(r'^(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(text)) {
    return null;
  }
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value < 0) {
    return null;
  }
  return value;
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots();

  final _search = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  final Set<String> _deletingIds = {};

  @override
  void dispose() {
    _search.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  Future<void> _createOrUpdate(
    [QueryDocumentSnapshot<Map<String, dynamic>>? document]
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => ProductEditor(
        products: _products,
        document: document,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteProduct(String id) async {
    if (_deletingIds.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete the product with document ID $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _deletingIds.add(id);
    });

    try {
      // Use the Firestore ID, never a name or a list index.
      await _products.doc(id).delete();
      if (!mounted) return;
      _showMessage('Product deleted successfully.');
    } on FirebaseException catch (error) {
      debugPrint('Product delete failed (${error.code}): ${error.message}');
      if (!mounted) return;
      _showMessage(
        'Delete failed (${error.code}). Check connection and permissions.',
      );
    } catch (error) {
      debugPrint('Unexpected product delete error: $error');
      if (!mounted) return;
      _showMessage('Delete failed. Check your connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(id);
        });
      }
    }
  }

  String? _filterError() {
    final minText = _minPrice.text.trim();
    final maxText = _maxPrice.text.trim();
    final min = minText.isEmpty ? null : parseProductPrice(minText);
    final max = maxText.isEmpty ? null : parseProductPrice(maxText);

    if (minText.isNotEmpty && min == null) {
      return 'Minimum price must be a finite, nonnegative number (e.g. 12.50).';
    }
    if (maxText.isNotEmpty && max == null) {
      return 'Maximum price must be a finite, nonnegative number (e.g. 20).';
    }
    if (min != null && max != null && min > max) {
      return 'Minimum price cannot exceed maximum price.';
    }
    return null;
  }

  void _resetFilters() {
    _search.clear();
    _minPrice.clear();
    _maxPrice.clear();
    setState(() {});
  }

  Widget _buildProductList({
    required String searchText,
    required double? min,
    required double? max,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Products could not load. Check connection and permissions.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs;
        if (documents.isEmpty) {
          return const Center(
            child: Text('No products yet. Add one to begin.'),
          );
        }

        // Filter the same stable stream locally for this small teaching dataset.
        final validDocuments = documents.where((document) {
          final data = document.data();
          final name = data['name'];
          final price = data['price'];
          return name is String &&
              name.trim().isNotEmpty &&
              price is num &&
              price.isFinite &&
              price >= 0;
        }).toList();

        final skippedCount = documents.length - validDocuments.length;
        final visibleDocuments = validDocuments.where((document) {
          final data = document.data();
          final name = (data['name'] as String).trim().toLowerCase();
          final price = (data['price'] as num).toDouble();
          return name.contains(searchText) &&
              (min == null || price >= min) &&
              (max == null || price <= max);
        }).toList();

        return Column(
          children: [
            if (skippedCount > 0)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$skippedCount product(s) have invalid name/price fields '
                  'and are not shown.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: visibleDocuments.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : ListView.builder(
                      itemCount: visibleDocuments.length,
                      itemBuilder: (context, index) {
                        final document = visibleDocuments[index];
                        final data = document.data();
                        final name = data['name'] as String;
                        final price = data['price'] as num;
                        final deleting = _deletingIds.contains(document.id);
                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(
                              '\$${price.toStringAsFixed(2)}\nID: ${document.id}',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit product',
                                  icon: const Icon(Icons.edit),
                                  onPressed: deleting
                                      ? null
                                      : () => _createOrUpdate(document),
                                ),
                                if (deleting)
                                  const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  IconButton(
                                    tooltip: 'Delete product',
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteProduct(document.id),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterError = _filterError();
    final searchText = _search.text.trim().toLowerCase();
    final min = _minPrice.text.trim().isEmpty
        ? null
        : parseProductPrice(_minPrice.text);
    final max = _maxPrice.text.trim().isEmpty
        ? null
        : parseProductPrice(_maxPrice.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search products by name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Min price',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Max price',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                if (filterError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      filterError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filterError != null
                ? const Center(
                    child: Text('Correct the price filters to view products.'),
                  )
                : _buildProductList(
                    searchText: searchText,
                    min: min,
                    max: max,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create product',
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({
    super.key,
    required this.products,
    this.document,
  });

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.document?.data()['name'] as String? ?? '',
  );
  late final _price = TextEditingController(
    text: widget.document?.data()['price']?.toString() ?? '',
  );
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final data = <String, Object>{
      'name': _name.text.trim(),
      'price': parseProductPrice(_price.text)!,
    };
    try {
      final document = widget.document;
      if (document == null) {
        await widget.products.add(data);
      } else {
        await widget.products.doc(document.id).update(data);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint('Product save failed (${error.code}): ${error.message}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed (${error.code}). '
            'Check your connection and permissions.';
      });
    } catch (error) {
      debugPrint('Unexpected product save error: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.document == null ? 'Create product' : 'Edit product'),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) =>
                      parseProductPrice(value ?? '') == null
                          ? 'Enter a finite price of zero or more (e.g. 12.50)'
                          : null,
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving)
                  const Text(
                    'Awaiting server acknowledgement. If offline, reconnect. '
                    'This editor stays open until the write succeeds or fails.',
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

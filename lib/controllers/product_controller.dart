import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';
import 'package:backend/services/sales_realtime_service.dart';

class ProductController extends Controller {
  Future<Response> categories() async {
    final rows = await DB.query(
      '''
      SELECT categories.*
      FROM categories
      WHERE categories.company_id = ?
        AND categories.deleted_at IS NULL
      ORDER BY categories.name
      ''',
      positionalParams: [_authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Categories retrieved successfully',
    ));
  }

  Future<Response> createCategory() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({'name': 'required|string'});
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }

    if (body['parent_id'] != null &&
        await _findCategory(body['parent_id']) == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'parent_id is invalid.',
          ));
    }

    await DB.query(
      '''
      INSERT INTO categories
        (id, company_id, parent_id, name, description, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        body['parent_id'],
        body['name'],
        body['description'],
        body['status'] ?? 'active',
      ],
    );

    final category = await _first(
      '''
      SELECT * FROM categories
      WHERE company_id = ? AND name = ? AND deleted_at IS NULL
      ORDER BY id DESC
      LIMIT 1
      ''',
      [_authContext['company_id'], body['name']],
    );

    return res.status(201).json(ApiResponse.success(
          data: category,
          message: 'Category created successfully',
        ));
  }

  Future<Response> updateCategory() async {
    final categoryId = req.params['id'];
    final category = await _findCategory(categoryId);
    if (category == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Category not found.',
          ));
    }

    final body = await req.json();
    if (body['parent_id'] != null &&
        await _findCategory(body['parent_id']) == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'parent_id is invalid.',
          ));
    }

    const allowedFields = {'parent_id', 'name', 'description', 'status'};
    final updates = _allowedUpdates(body, allowedFields);
    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE categories
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          categoryId,
          _authContext['company_id'],
        ],
      );
    }

    return res.json(ApiResponse.success(
      data: await _findCategory(categoryId),
      message: 'Category updated successfully',
    ));
  }

  Future<Response> index() async {
    final query = req.queryParam('q')?.trim();
    final categoryId = req.queryParam('category_id');
    final status = req.queryParam('status');

    final where = [
      'products.company_id = ?',
      'products.deleted_at IS NULL',
    ];
    final params = <dynamic>[_authContext['company_id']];

    if (query != null && query.isNotEmpty) {
      where.add(
        '(products.name LIKE ? OR products.sku LIKE ? OR products.barcode LIKE ? OR products.brand LIKE ?)',
      );
      final like = '%$query%';
      params.addAll([like, like, like, like]);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      where.add('products.category_id = ?');
      params.add(categoryId);
    }

    if (status != null && status.isNotEmpty) {
      where.add('products.status = ?');
      params.add(status);
    }

    final rows = await DB.query(
      '''
      SELECT
        products.*,
        categories.name AS category_name
      FROM products
      LEFT JOIN categories ON categories.id = products.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY products.name
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Products retrieved successfully',
    ));
  }

  Future<Response> create() async {
    final productId = Str.uuid();
    final body = _normalizeProductBody(
      await req.json(),
      fallbackSku: 'PRD-${productId.substring(0, 8).toUpperCase()}',
    );
    final validationError = await _validateProductBody(body);
    if (validationError != null) return validationError;

    final duplicate = await _duplicateProduct(
      sku: body['sku'],
      barcode: body['barcode'],
    );
    if (duplicate != null) {
      return _conflict('A product with this SKU or barcode already exists.');
    }

    await DB.query(
      '''
      INSERT INTO products
        (id, company_id, category_id, sku, barcode, name, description, brand, unit,
         cost_price, selling_price, reorder_level, has_variants, status,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        productId,
        _authContext['company_id'],
        body['category_id'],
        body['sku'],
        body['barcode'],
        body['name'],
        body['description'],
        body['brand'],
        body['unit'],
        body['cost_price'],
        body['selling_price'],
        body['reorder_level'] ?? 0,
        body['has_variants'] ?? false,
        body['status'] ?? 'active',
      ],
    );

    final product = await _first(
      '''
      SELECT * FROM products
      WHERE company_id = ? AND sku = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [_authContext['company_id'], body['sku']],
    );

    await _seedInitialInventory(productId, body);
    _emitProductChanged('created', productId: productId);

    return res.status(201).json(ApiResponse.success(
          data: product,
          message: 'Product created successfully',
        ));
  }

  Future<Response> show() async {
    final product = await _findProduct(req.params['id']);
    if (product == null) return _productNotFound();

    final variants = await DB.query(
      '''
      SELECT * FROM product_variants
      WHERE product_id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      ORDER BY variant_name
      ''',
      positionalParams: [req.params['id'], _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: {
        ...product,
        'variants': variants,
      },
      message: 'Product retrieved successfully',
    ));
  }

  Future<Response> update() async {
    final productId = req.params['id'];
    final product = await _findProduct(productId);
    if (product == null) return _productNotFound();

    final body = _normalizeProductBody(
      await req.json(),
      partial: true,
      fallbackSku: 'PRD-${productId.toString().substring(0, 8).toUpperCase()}',
    );
    final validationError = await _validateProductBody(body, partial: true);
    if (validationError != null) return validationError;

    final duplicate = await _duplicateProduct(
      sku: body['sku'],
      barcode: body['barcode'],
      exceptProductId: productId,
    );
    if (duplicate != null) {
      return _conflict('A product with this SKU or barcode already exists.');
    }

    const allowedFields = {
      'category_id',
      'sku',
      'barcode',
      'name',
      'description',
      'brand',
      'unit',
      'cost_price',
      'selling_price',
      'reorder_level',
      'has_variants',
      'status',
    };
    final updates = _allowedUpdates(body, allowedFields);
    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE products
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          productId,
          _authContext['company_id'],
        ],
      );
    }

    final updatedProduct = await _findProduct(productId);
    _emitProductChanged('updated', productId: productId);

    return res.json(ApiResponse.success(
      data: updatedProduct,
      message: 'Product updated successfully',
    ));
  }

  Future<Response> delete() async {
    final productId = req.params['id'];
    final product = await _findProduct(productId);
    if (product == null) return _productNotFound();

    await DB.query(
      '''
      UPDATE products
      SET status = ?, deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['inactive', productId, _authContext['company_id']],
    );
    _emitProductChanged('deleted', productId: productId);

    return res.json(ApiResponse.success(
      message: 'Product deactivated successfully',
    ));
  }

  Future<Response> createVariant() async {
    final productId = req.params['id'];
    final product = await _findProduct(productId);
    if (product == null) return _productNotFound();

    Map<String, dynamic> body;
    try {
      body = await req.validate({
        'sku': 'required|string',
        'variant_name': 'required|string',
      });
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }
    final validationError = await _validateVariantBody(body);
    if (validationError != null) return validationError;

    final duplicate = await _duplicateVariant(
      sku: body['sku'],
      barcode: body['barcode'],
    );
    if (duplicate != null) {
      return _conflict('A variant with this SKU or barcode already exists.');
    }

    await DB.query(
      '''
      INSERT INTO product_variants
        (id, company_id, product_id, sku, barcode, variant_name, attributes_json,
         cost_price, selling_price, reorder_level, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        productId,
        body['sku'],
        body['barcode'],
        body['variant_name'],
        body['attributes_json'],
        body['cost_price'] ?? product['cost_price'],
        body['selling_price'] ?? product['selling_price'],
        body['reorder_level'] ?? product['reorder_level'],
        body['status'] ?? 'active',
      ],
    );

    await DB.query(
      '''
      UPDATE products
      SET has_variants = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [true, productId, _authContext['company_id']],
    );

    final variant = await _first(
      '''
      SELECT * FROM product_variants
      WHERE company_id = ? AND sku = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [_authContext['company_id'], body['sku']],
    );
    _emitProductChanged(
      'variant_created',
      productId: productId,
      variantId: variant?['id'],
    );

    return res.status(201).json(ApiResponse.success(
          data: variant,
          message: 'Product variant created successfully',
        ));
  }

  Future<Response> updateVariant() async {
    final variantId = req.params['id'];
    final variant = await _findVariant(variantId);
    if (variant == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Product variant not found.',
          ));
    }

    final body = await req.json();
    final validationError = await _validateVariantBody(body, partial: true);
    if (validationError != null) return validationError;

    final duplicate = await _duplicateVariant(
      sku: body['sku'],
      barcode: body['barcode'],
      exceptVariantId: variantId,
    );
    if (duplicate != null) {
      return _conflict('A variant with this SKU or barcode already exists.');
    }

    const allowedFields = {
      'sku',
      'barcode',
      'variant_name',
      'attributes_json',
      'cost_price',
      'selling_price',
      'reorder_level',
      'status',
    };
    final updates = _allowedUpdates(body, allowedFields);
    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE product_variants
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          variantId,
          _authContext['company_id'],
        ],
      );
    }

    final updatedVariant = await _findVariant(variantId);
    _emitProductChanged(
      'variant_updated',
      productId: updatedVariant?['product_id'],
      variantId: variantId,
    );

    return res.json(ApiResponse.success(
      data: updatedVariant,
      message: 'Product variant updated successfully',
    ));
  }

  Future<Response> barcodeLookup() async {
    final barcode = req.params['barcode'];
    final product = await _first(
      '''
      SELECT 'product' AS match_type, products.*
      FROM products
      WHERE company_id = ?
        AND barcode = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [_authContext['company_id'], barcode],
    );
    if (product != null) {
      return res.json(ApiResponse.success(
        data: product,
        message: 'Barcode match retrieved successfully',
      ));
    }

    final variant = await _first(
      '''
      SELECT
        'variant' AS match_type,
        product_variants.*,
        products.name AS product_name
      FROM product_variants
      INNER JOIN products ON products.id = product_variants.product_id
      WHERE product_variants.company_id = ?
        AND product_variants.barcode = ?
        AND product_variants.deleted_at IS NULL
      LIMIT 1
      ''',
      [_authContext['company_id'], barcode],
    );

    if (variant == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'No product or variant found for this barcode.',
          ));
    }

    return res.json(ApiResponse.success(
      data: variant,
      message: 'Barcode match retrieved successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Map<String, dynamic> _allowedUpdates(
    Map<String, dynamic> body,
    Set<String> allowedFields,
  ) {
    final updates = <String, dynamic>{};
    for (final entry in body.entries) {
      if (allowedFields.contains(entry.key)) {
        updates[entry.key] = entry.value;
      }
    }
    return updates;
  }

  Future<Response?> _validateProductBody(
    Map<String, dynamic> body, {
    bool partial = false,
  }) async {
    if (body['category_id'] != null &&
        await _findCategory(body['category_id']) == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'category_id is invalid.',
          ));
    }

    final status = body['status']?.toString();
    if (status != null && !{'active', 'inactive'}.contains(status)) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'status must be active or inactive.',
          ));
    }

    for (final field in [
      'cost_price',
      'selling_price',
      'reorder_level',
      'opening_stock',
    ]) {
      if (body[field] != null && _asDouble(body[field]) == null) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: '$field must be a valid number.',
            ));
      }
    }

    return Future<Response?>.value();
  }

  Map<String, dynamic> _normalizeProductBody(
    Map<String, dynamic> body, {
    bool partial = false,
    required String fallbackSku,
  }) {
    final normalized = Map<String, dynamic>.from(body);
    final blankDefaults = {
      'sku': fallbackSku,
      'name': 'Untitled product',
      'unit': 'pcs',
      'cost_price': 0,
      'selling_price': 0,
      'reorder_level': 0,
    };

    for (final entry in blankDefaults.entries) {
      if (!partial || normalized.containsKey(entry.key)) {
        normalized[entry.key] = _blankToDefault(
          normalized[entry.key],
          entry.value,
        );
      }
    }

    for (final field in ['barcode', 'description', 'brand']) {
      if (normalized.containsKey(field)) {
        normalized[field] = _blankToNull(normalized[field]);
      }
    }

    if (normalized.containsKey('opening_stock')) {
      normalized['opening_stock'] = _blankToDefault(
        normalized['opening_stock'],
        0,
      );
    }

    return normalized;
  }

  Object? _blankToDefault(Object? value, Object fallback) {
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value;
  }

  Object? _blankToNull(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return value;
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _seedInitialInventory(
    Object productId,
    Map<String, dynamic> body,
  ) async {
    final quantity = _asDouble(body['opening_stock']) ?? 0;
    if (quantity <= 0) return;

    final store = await _first(
      '''
      SELECT id FROM stores
      WHERE company_id = ?
        AND deleted_at IS NULL
      ORDER BY created_at ASC
      LIMIT 1
      ''',
      [_authContext['company_id']],
    );
    if (store == null) return;

    final inventoryId = Str.uuid();
    final cost = _asDouble(body['cost_price']) ?? 0;
    await DB.query(
      '''
      INSERT INTO inventory
        (id, company_id, store_id, product_id, product_variant_id,
         quantity_on_hand, quantity_reserved, quantity_available,
         average_cost, reorder_level, last_movement_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        inventoryId,
        _authContext['company_id'],
        store['id'],
        productId,
        quantity,
        0,
        quantity,
        cost,
        _asDouble(body['reorder_level']) ?? 0,
      ],
    );

    await DB.query(
      '''
      INSERT INTO inventory_transactions
        (id, company_id, store_id, product_id, product_variant_id, type, quantity,
         unit_cost, quantity_before, quantity_after, reference_type,
         reference_id, reason, created_by, created_at)
      VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        store['id'],
        productId,
        'stock_in',
        quantity,
        cost,
        0,
        quantity,
        'product',
        productId,
        'Opening stock',
        (_authContext['user'] as Map)['id'],
      ],
    );
  }

  Future<Response?> _validateVariantBody(
    Map<String, dynamic> body, {
    bool partial = false,
  }) {
    if (!partial) {
      for (final field in ['sku', 'variant_name']) {
        if (body[field] == null || body[field].toString().trim().isEmpty) {
          return res.status(422).json(ApiResponse.error(
                code: 'VALIDATION_ERROR',
                message: '$field is required.',
              ));
        }
      }
    }

    final status = body['status']?.toString();
    if (status != null && !{'active', 'inactive'}.contains(status)) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'status must be active or inactive.',
          ));
    }

    return Future<Response?>.value();
  }

  Future<Map<String, dynamic>?> _findCategory(Object? id) {
    return _first(
      '''
      SELECT * FROM categories
      WHERE id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findProduct(Object? id) {
    return _first(
      '''
      SELECT
        products.*,
        categories.name AS category_name
      FROM products
      LEFT JOIN categories ON categories.id = products.category_id
      WHERE products.id = ?
        AND products.company_id = ?
        AND products.deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findVariant(Object? id) {
    return _first(
      '''
      SELECT * FROM product_variants
      WHERE id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _duplicateProduct({
    Object? sku,
    Object? barcode,
    Object? exceptProductId,
  }) {
    if ((sku == null || sku.toString().isEmpty) &&
        (barcode == null || barcode.toString().isEmpty)) {
      return Future<Map<String, dynamic>?>.value();
    }

    final clauses = <String>[];
    final params = <dynamic>[_authContext['company_id']];
    if (sku != null && sku.toString().isNotEmpty) {
      clauses.add('sku = ?');
      params.add(sku);
    }
    if (barcode != null && barcode.toString().isNotEmpty) {
      clauses.add('barcode = ?');
      params.add(barcode);
    }
    if (exceptProductId != null) {
      params.add(exceptProductId);
    }

    return _first(
      '''
      SELECT id FROM products
      WHERE company_id = ?
        AND (${clauses.join(' OR ')})
        ${exceptProductId == null ? '' : 'AND id <> ?'}
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      params,
    );
  }

  Future<Map<String, dynamic>?> _duplicateVariant({
    Object? sku,
    Object? barcode,
    Object? exceptVariantId,
  }) {
    if ((sku == null || sku.toString().isEmpty) &&
        (barcode == null || barcode.toString().isEmpty)) {
      return Future<Map<String, dynamic>?>.value();
    }

    final clauses = <String>[];
    final params = <dynamic>[_authContext['company_id']];
    if (sku != null && sku.toString().isNotEmpty) {
      clauses.add('sku = ?');
      params.add(sku);
    }
    if (barcode != null && barcode.toString().isNotEmpty) {
      clauses.add('barcode = ?');
      params.add(barcode);
    }
    if (exceptVariantId != null) {
      params.add(exceptVariantId);
    }

    return _first(
      '''
      SELECT id FROM product_variants
      WHERE company_id = ?
        AND (${clauses.join(' OR ')})
        ${exceptVariantId == null ? '' : 'AND id <> ?'}
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      params,
    );
  }

  Future<Map<String, dynamic>?> _first(
    String sql,
    List<dynamic> params,
  ) async {
    final rows = await DB.query(sql, positionalParams: params);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void _emitProductChanged(
    String action, {
    required Object? productId,
    Object? variantId,
  }) {
    SalesRealtimeService.productChanged(
      action: action,
      companyId: _authContext['company_id'],
      productId: productId,
      variantId: variantId,
    );
  }

  Future<Response> _conflict(String message) {
    return res.status(409).json(ApiResponse.error(
          code: 'CONFLICT',
          message: message,
        ));
  }

  Future<Response> _productNotFound() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Product not found.',
        ));
  }
}

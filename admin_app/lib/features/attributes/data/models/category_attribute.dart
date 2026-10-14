/// Mirrors the `category_attributes` table.
enum AttributeType {
  text,
  number,
  boolean,
  select;

  /// DB/JSON wire value.
  String get dbValue => name; // 'text','number','boolean','select'

  /// Display label shown in the UI.
  String get label {
    switch (this) {
      case AttributeType.text:
        return 'TEXT';
      case AttributeType.number:
        return 'NUMBER';
      case AttributeType.boolean:
        return 'BOOLEAN';
      case AttributeType.select:
        return 'SELECT';
    }
  }

  static AttributeType fromDb(String v) {
    switch (v) {
      case 'text':
        return AttributeType.text;
      case 'number':
        return AttributeType.number;
      case 'boolean':
        return AttributeType.boolean;
      case 'select':
        return AttributeType.select;
      default:
        return AttributeType.text;
    }
  }
}

class CategoryAttribute {
  const CategoryAttribute({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.attributeKey,
    required this.dataType,
    required this.options,
    required this.isRequired,
    required this.displayOrder,
    required this.isActive,
  });

  final String id;
  final String categoryId;
  final String name;
  final String attributeKey;
  final AttributeType dataType;

  /// Option strings — only meaningful when [dataType] == [AttributeType.select].
  final List<String> options;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;

  factory CategoryAttribute.fromJson(Map<String, dynamic> json) =>
      CategoryAttribute(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        name: json['name'] as String,
        attributeKey: json['attribute_key'] as String,
        dataType: AttributeType.fromDb(json['data_type'] as String),
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        isRequired: json['is_required'] as bool? ?? false,
        displayOrder: json['display_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'name': name,
        'attribute_key': attributeKey,
        'data_type': dataType.dbValue,
        'options': options,
        'is_required': isRequired,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  CategoryAttribute copyWith({
    String? name,
    List<String>? options,
    bool? isRequired,
    int? displayOrder,
    bool? isActive,
  }) =>
      CategoryAttribute(
        id: id,
        categoryId: categoryId,
        name: name ?? this.name,
        attributeKey: attributeKey,
        dataType: dataType,
        options: options ?? this.options,
        isRequired: isRequired ?? this.isRequired,
        displayOrder: displayOrder ?? this.displayOrder,
        isActive: isActive ?? this.isActive,
      );
}

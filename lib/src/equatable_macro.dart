import 'package:collection/collection.dart';
import 'package:data_class_macro/src/macro_extensions.dart';
import 'package:macros/macros.dart';

/// {@template equatable}
/// An experimental macro which implements value-equality.
/// 
/// ```dart
/// @Equatable()
/// class Person {
///   const Person({required this.name});
///   final String name;
/// }
/// 
/// void main() {
///   // Generated `hashCode` and `operator==` for value based equality.
///   print(Person(name: 'Dash') == Person(name: 'Dash')); // true
///   print(Person(name: 'Dash') == Person(name: 'Sparky')); // false
/// }
/// ```
/// {@endtemplate}
macro class Equatable implements ClassDeclarationsMacro, ClassDefinitionMacro {
  /// {@macro equatable}
  const Equatable();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) {
    return Future.wait([
      _declareEquals(clazz, builder),
      _declareHashCode(clazz, builder),
    ]);
  }

  @override
  Future<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) {
    return Future.wait([
      _buildEquals(clazz, builder),
      _buildHashCode(clazz, builder),
    ]);
  }

  Future<void> _declareEquals(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    return builder.declareInType(
      DeclarationCode.fromString('external bool operator==(Object other);'),
    );
  }

  Future<void> _declareHashCode(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    return builder.declareInType(
      DeclarationCode.fromString('external int get hashCode;'),
    );
  }

  Future<void> _buildEquals(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final methods = await builder.methodsOf(clazz);
    final equality = methods.firstWhereOrNull(
      (m) => m.identifier.name == '==',
    );
    if (equality == null) return;
    final equalsMethod = await builder.buildMethod(equality.identifier);
    final deepCollectionEquality = await builder.getIdentifier(
      Uri.parse('package:data_class_macro/data_class_macro.dart'),
      'deepCollectionEquality',
    );
    final fieldDeclarations = await builder.fieldsOf(clazz);
    final fields = fieldDeclarations.map(
      (f) => f.identifier.name,
    );
    final identical = await builder.getIdentifier(
      Uri.parse('dart:core'),
      'identical',
    );
    
    if (fields.isEmpty) {
      return equalsMethod.augment(
        FunctionBodyCode.fromParts(
          [
            '{',
            'if (', NamedTypeAnnotationCode(name: identical),' (this, other)',')', 'return true;',
            'return other is ${clazz.identifier.name} && ',
            'other.runtimeType == runtimeType;',            
            '}',          
          ],
        ),      
      );
    }
    
    final lastField = fields.last;
    return equalsMethod.augment(
      FunctionBodyCode.fromParts(
        [
          '{',
          'if (', NamedTypeAnnotationCode(name: identical),' (this, other)',')', 'return true;',
          'return other is ${clazz.identifier.name} && ',
          'other.runtimeType == runtimeType && ',          
          for (final field in fields)
            ...[NamedTypeAnnotationCode(name: deepCollectionEquality), '.equals(${field}, other.$field)', if (field != lastField) '&& '],
          ';',
          '}',          
        ],
      ),      
    );
  }

  Future<void> _buildHashCode(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final methods = await builder.methodsOf(clazz);
    final hashCode = methods.firstWhereOrNull(
      (m) => m.identifier.name == 'hashCode',
    );
    if (hashCode == null) return;
    final hashCodeMethod = await builder.buildMethod(hashCode.identifier);
    final object = await builder.getIdentifier(
      Uri.parse('dart:core'),
      'Object',
    );
    final fieldDeclarations = await builder.fieldsOf(clazz);
    final fields = fieldDeclarations.map(
      (f) => f.identifier.name,
    );

    return hashCodeMethod.augment(
      FunctionBodyCode.fromParts(
        [
          '=> ',
          NamedTypeAnnotationCode(name: object),
          '.hashAll([',
          fields.join(', '),
          ']);',
        ],
      ),
    );
  }
}

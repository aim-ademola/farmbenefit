import 'package:flint_dart/schema.dart';

Column stringColumn(String name, {int length = 255, bool nullable = false}) =>
    Column(
      name: name,
      type: ColumnType.string,
      length: length,
      isNullable: nullable,
    );

Column textColumn(String name, {bool nullable = true}) => Column(
      name: name,
      type: ColumnType.text,
      isNullable: nullable,
    );

Column foreignIdColumn(String name, {bool nullable = false}) => Column(
      name: name,
      type: ColumnType.string,
      isNullable: nullable,
    );

Column moneyColumn(
  String name, {
  bool nullable = false,
  double defaultValue = 0,
}) =>
    Column(
      name: name,
      type: ColumnType.double,
      isNullable: nullable,
      defaultValue: defaultValue,
    );

Column boolColumn(String name, {bool defaultValue = false}) => Column(
      name: name,
      type: ColumnType.boolean,
      defaultValue: defaultValue,
    );

Column intColumn(String name, {int defaultValue = 0}) => Column(
      name: name,
      type: ColumnType.integer,
      defaultValue: defaultValue,
    );

Column jsonColumn(String name, {bool nullable = true}) => Column(
      name: name,
      type: ColumnType.json,
      isNullable: nullable,
    );

Column dateTimeColumn(String name, {bool nullable = true}) => Column(
      name: name,
      type: ColumnType.datetime,
      isNullable: nullable,
    );

Column deletedAtColumn() => dateTimeColumn('deleted_at');

Table schemaTable(
  String name,
  List<Column> columns, {
  List<Index> indexes = const [],
}) {
  return Table(
    name: name,
    columns: columns,
    indexes: indexes,
  );
}

import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class User extends Model<User> {
  User() : super(() => User());

  String? get firstName => getAttribute("first_name");
  String? get lastName => getAttribute("last_name");
  String? get email => getAttribute("email");
  String? get username => getAttribute("username");
  String? get passwordHash => getAttribute("password_hash");

  @override
  List<String> get conceal => ["password_hash"];

  @override
  Table get table => schemaTable('users', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id', nullable: true),
        foreignIdColumn('role_id'),
        stringColumn('first_name'),
        stringColumn('last_name'),
        stringColumn('email'),
        stringColumn('phone', nullable: true),
        stringColumn('username'),
        stringColumn('password_hash'),
        stringColumn('status', length: 40),
        dateTimeColumn('last_login_at'),
        deletedAtColumn(),
      ]);
}

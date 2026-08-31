/// The two account types in Kafelo. Stored in Firestore under
/// `users/{uid}` so sign-in can verify a person is using the login page
/// that matches how their account was actually created.
enum UserRole { customer, owner }

extension UserRoleX on UserRole {
  /// The exact string stored in Firestore for this role.
  String get value => this == UserRole.customer ? 'customer' : 'owner';

  /// Human-readable name shown in error messages / UI.
  String get label => this == UserRole.customer ? 'Coffee Explorer' : 'Coffee Shop Owner';

  static UserRole? fromValue(String? value) {
    switch (value) {
      case 'customer':
        return UserRole.customer;
      case 'owner':
        return UserRole.owner;
      default:
        return null;
    }
  }
}

/// Firestore collection where each user's role/profile document lives.
const String usersCollection = 'users';
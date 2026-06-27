// auth_models.dart
// Models for authentication and user session management.

class LoginRequest {
  final String userId;
  final String password;
  final String role;

  const LoginRequest({
    required this.userId,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'password': password,
        'role': role,
      };
}

class UserSession {
  final String token;
  final String userId;
  final String name;
  final String role;

  const UserSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      token:  json['token']   as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name:   json['name']    as String? ?? '',
      role:   json['role']    as String? ?? '',
    );
  }

  bool get isNurse => role == 'Triage Nurse';
  bool get isDoctor => role == 'Emergency Doctor';
  bool get isAdmin  => role == 'Administrator';
}

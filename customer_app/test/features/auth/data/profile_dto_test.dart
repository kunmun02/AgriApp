import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/auth/data/models/profile.dart';

void main() {
  group('ProfileRole.fromJson', () {
    test('fromJson role customer', () {
      final p = Profile.fromJson({
        'id': 'abc',
        'full_name': 'Test User',
        'email': 'test@example.com',
        'phone': null,
        'role': 'customer',
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      expect(p.role, ProfileRole.customer);
    });

    test('fromJson role admin', () {
      final p = Profile.fromJson({
        'id': 'abc',
        'full_name': 'Admin User',
        'email': 'admin@example.com',
        'phone': null,
        'role': 'admin',
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      expect(p.role, ProfileRole.admin);
    });

    test('unknown role maps to customer', () {
      final p = Profile.fromJson({
        'id': 'abc',
        'full_name': 'Unknown',
        'email': 'u@example.com',
        'phone': null,
        'role': 'superadmin', // not a recognised value
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      expect(p.role, ProfileRole.customer);
    });
  });

  group('Profile.fromJson', () {
    test('parses all fields correctly', () {
      const raw = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'full_name': 'Ravi Kumar',
        'email': 'ravi@example.com',
        'phone': '9876543210',
        'role': 'customer',
        'is_active': true,
        'created_at': '2024-06-15T10:30:00.000Z',
      };
      final p = Profile.fromJson(raw);
      expect(p.id, raw['id']);
      expect(p.fullName, raw['full_name']);
      expect(p.email, raw['email']);
      expect(p.phone, raw['phone']);
      expect(p.role, ProfileRole.customer);
      expect(p.isActive, true);
      expect(p.createdAt.year, 2024);
    });

    test('null phone is preserved', () {
      final p = Profile.fromJson({
        'id': 'x',
        'full_name': 'A',
        'email': 'a@b.com',
        'phone': null,
        'role': 'customer',
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      expect(p.phone, isNull);
    });

    test('copyWith updates only specified fields', () {
      final original = Profile.fromJson({
        'id': 'x',
        'full_name': 'Original',
        'email': 'o@b.com',
        'phone': null,
        'role': 'customer',
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      final copy = original.copyWith(fullName: 'Updated');
      expect(copy.fullName, 'Updated');
      expect(copy.email, original.email);
      expect(copy.id, original.id);
    });
  });
}

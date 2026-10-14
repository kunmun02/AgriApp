import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/core/errors/app_failure.dart';
import 'package:customer_app/core/errors/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppFailure', () {
    test('ApiFailure has correct code and message', () {
      const f = ApiFailure('OUT_OF_STOCK', 'Not enough stock');
      expect(f.code, 'OUT_OF_STOCK');
      expect(f.message, 'Not enough stock');
      expect(f.userMessage, 'Not enough stock');
    });

    test('NetworkFailure has NETWORK_ERROR code', () {
      const f = NetworkFailure();
      expect(f.code, 'NETWORK_ERROR');
    });

    test('ValidationFailure has VALIDATION_ERROR code', () {
      const f = ValidationFailure('Invalid email');
      expect(f.code, 'VALIDATION_ERROR');
      expect(f.message, 'Invalid email');
    });
  });

  group('ErrorMapper', () {
    test('Rule 1: SocketException → NetworkFailure', () {
      final f = ErrorMapper.from(const SocketException('no route to host'));
      expect(f, isA<NetworkFailure>());
      expect(f.code, 'NETWORK_ERROR');
    });

    test('Rule 4: P0001 with JSON envelope → typed ApiFailure', () {
      final envelope = jsonEncode({
        'code': 'OUT_OF_STOCK',
        'message': 'insufficient stock for Tomato Seeds',
        'details': {'product_id': 'abc', 'available': 0},
      });
      final ex = PostgrestException(message: envelope, code: 'P0001');
      final f = ErrorMapper.from(ex);
      expect(f, isA<ApiFailure>());
      expect(f.code, 'OUT_OF_STOCK');
      expect(f.message, 'insufficient stock for Tomato Seeds');
      expect(f.details?['available'], 0);
    });

    test('Rule 4: P0001 with non-JSON message → INTERNAL_ERROR', () {
      const ex =
          PostgrestException(message: 'some raw error text', code: 'P0001');
      final f = ErrorMapper.from(ex);
      expect(f, isA<ApiFailure>());
      expect(f.code, 'INTERNAL_ERROR');
    });

    test('Rule 5: PGRST116 → NOT_FOUND', () {
      const ex = PostgrestException(message: '', code: 'PGRST116');
      final f = ErrorMapper.from(ex);
      expect(f.code, 'NOT_FOUND');
    });

    test('Rule 5: 42501 → FORBIDDEN', () {
      const ex =
          PostgrestException(message: 'permission denied', code: '42501');
      final f = ErrorMapper.from(ex);
      expect(f.code, 'FORBIDDEN');
    });

    test('Rule 5: PGRST301 → AUTH_REQUIRED', () {
      const ex = PostgrestException(message: '', code: 'PGRST301');
      final f = ErrorMapper.from(ex);
      expect(f.code, 'AUTH_REQUIRED');
    });

    test('Unmapped code → INTERNAL_ERROR', () {
      const ex = PostgrestException(message: 'weird', code: '99999');
      final f = ErrorMapper.from(ex);
      expect(f.code, 'INTERNAL_ERROR');
    });

    test('Unknown exception type → INTERNAL_ERROR', () {
      final f = ErrorMapper.from(Exception('unexpected'));
      expect(f.code, 'INTERNAL_ERROR');
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import 'network_providers.dart';

/// Support contact details set by the admin (Business settings): shown on
/// Help & Support, Privacy, Terms and About instead of hard-coded values.
class SupportContact {
  const SupportContact({
    required this.companyName,
    required this.email,
    required this.phone,
    required this.address,
  });

  final String companyName;
  final String email;
  final String phone;
  final String address;

  bool get hasEmail => email.isNotEmpty;
  bool get hasPhone => phone.isNotEmpty;

  static const empty =
      SupportContact(companyName: 'Cravioo', email: '', phone: '', address: '');
}

/// GET /food/admin/business-settings/public (no login needed).
final supportContactProvider = FutureProvider<SupportContact>((ref) async {
  final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
        ApiPaths.businessSettings,
        auth: false,
        cacheTtl: const Duration(hours: 6),
      );
  String str(Object? v) => v?.toString().trim() ?? '';

  // phone may be a plain string or {countryCode, number}.
  final rawPhone = data['phone'];
  final phone = rawPhone is Map
      ? (str(rawPhone['number'] ?? rawPhone['phone']).isEmpty
          ? ''
          : '${str(rawPhone['countryCode'])} ${str(rawPhone['number'] ?? rawPhone['phone'])}'.trim())
      : str(rawPhone);

  final address = data['address'];
  return SupportContact(
    companyName: str(data['companyName']).isNotEmpty ? str(data['companyName']) : 'Cravioo',
    email: str(data['email']),
    phone: phone,
    address: address is Map
        ? [address['line1'], address['city'], address['state']]
            .map(str)
            .where((s) => s.isNotEmpty)
            .join(', ')
        : str(address),
  );
});

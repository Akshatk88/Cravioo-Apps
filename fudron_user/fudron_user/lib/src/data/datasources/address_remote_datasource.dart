import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/address_model.dart';

/// `/food/user/addresses` (Bearer).
class AddressRemoteDataSource {
  final ApiClient _client;

  const AddressRemoteDataSource(this._client);

  Future<List<AddressModel>> getAddresses() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.addresses);
    return ((data['addresses'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AddressModel.fromApi(e.cast<String, dynamic>()))
        .toList();
  }

  Future<AddressModel> addAddress(AddressModel address) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.addresses,
      body: address.toApiPayload(),
    );
    return AddressModel.fromApi((data['address'] as Map).cast<String, dynamic>());
  }

  Future<AddressModel> updateAddress(AddressModel address) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '${ApiPaths.addresses}/${address.id}',
      body: address.toApiPayload(),
    );
    return AddressModel.fromApi((data['address'] as Map).cast<String, dynamic>());
  }

  Future<void> deleteAddress(String id) async {
    await _client.delete<dynamic>('${ApiPaths.addresses}/$id');
  }

  Future<AddressModel> setDefault(String id) async {
    final data = await _client.patch<Map<String, dynamic>>('${ApiPaths.addresses}/$id/default');
    return AddressModel.fromApi((data['address'] as Map).cast<String, dynamic>());
  }
}

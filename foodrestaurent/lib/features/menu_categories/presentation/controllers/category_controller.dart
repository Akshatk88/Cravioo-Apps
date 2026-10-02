import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/menu_categories/data/category_repository.dart';
import 'package:food_user_application/features/menu_categories/domain/category_model.dart';

class CategoryController extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() {
    return ref.read(categoryRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(categoryRepositoryProvider).list(),
    );
  }

  Future<void> create({
    required String name,
    required String foodTypeScope,
    String type = '',
    String image = '',
    bool isActive = true,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .create(
          name: name,
          foodTypeScope: foodTypeScope,
          type: type,
          image: image,
          isActive: isActive,
        );
    await refresh();
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    String? foodTypeScope,
    String? type,
    String? image,
    bool? isActive,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .update(
          id,
          name: name,
          foodTypeScope: foodTypeScope,
          type: type,
          image: image,
          isActive: isActive,
        );
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(categoryRepositoryProvider).delete(id);
    await refresh();
  }
}

final categoryControllerProvider =
    AsyncNotifierProvider<CategoryController, List<CategoryModel>>(
      CategoryController.new,
    );

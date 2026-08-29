import '../categories/category_catalogue.dart';
import '../categories/listing_catalogue.dart';
import '../home/product_showcase.dart';

/// Every product a search can turn up, and the matching itself.
///
/// Built by flattening every category group's own listing — the same
/// [ListingCatalogue] the category screens already show — rather than keeping
/// a second, separate product list that the catalogue could drift out of
/// step with. The three home showcases are folded in on top for anything that
/// is not already reachable through a category.
class SearchCatalogue {
  const SearchCatalogue._();

  /// The full, de-duplicated pool searches are matched against. Built once
  /// and kept — the catalogue behind it is all compile-time data, so there is
  /// nothing here that can go stale within a session.
  static final List<Product> all = _build();

  static List<Product> _build() {
    final seen = <String>{};
    final products = <Product>[];

    void addAll(Iterable<Product> items) {
      for (final product in items) {
        // Named products repeat across sub-categories and showcases — Accu-Chek
        // strips sit in both a home row and Diabetes Care — so a search result
        // is not the same product listed twice under one query.
        if (seen.add(product.name)) {
          products.add(product);
        }
      }
    }

    for (final group in CategoryCatalogue.groups) {
      addAll(ListingCatalogue.forGroup(group));
    }
    addAll(ProductCatalogue.popularItems);
    addAll(ProductCatalogue.dealsYouLove);
    addAll(ProductCatalogue.wellnessAndSupplements);

    return products;
  }

  /// Products whose name or pack contains [query], case-insensitively. Empty
  /// for a blank query rather than the whole catalogue — a query box that has
  /// not been typed into has not asked for anything yet.
  static List<Product> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return const [];
    }
    return all
        .where(
          (product) =>
              product.name.toLowerCase().contains(needle) ||
              product.pack.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  /// A handful of searches offered before anything has been typed.
  static const List<String> suggestions = [
    'Dolo 650',
    'Vitamin D3',
    'Protein Powder',
    'BP Monitor',
    'Sunscreen',
    'Multivitamin',
    'Test Strips',
    'Calcium',
  ];
}

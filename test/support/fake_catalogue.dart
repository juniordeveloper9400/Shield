import 'package:flutter/material.dart';
import 'package:shield/module/catalogue/catalogue_service.dart';
import 'package:shield/module/home/product_showcase.dart';

/// A small stand-in for `app.product` used by the catalogue widget tests.
///
/// The real catalogue is loaded from Neon at runtime; tests have no database,
/// so [seedFakeCatalogue] pushes this list straight into [CatalogueService].
/// It is deliberately shaped to exercise the category browser, the listing
/// filters, search and the home rows:
///
///  * every [CategoryCatalogue] group has at least one product, so
///    `brandsFor` is never empty;
///  * Personal Care spans several sub-categories and two named brands
///    (Cetaphil, Minimalist) for the filter tests;
///  * exactly one product is named "Dolo 650mg Tablet" / packed "Strip of 15
///    tablets" for the search-by-name and search-by-pack tests;
///  * two products are flagged `isPopular` and none `isOfferOfDay`, so the
///    home feed shows exactly the three always-on rows.
const List<Product> kFakeCatalogue = [
  // ---- Personal Care ----------------------------------------------------
  Product(
    id: 'fake-cetaphil',
    name: 'Cetaphil Oil Control Sunscreen SPF 30',
    pack: 'Bottle of 50 ml',
    price: '520',
    mrp: '635',
    discountLabel: '18% OFF',
    icon: Icons.wb_sunny_outlined,
    brand: 'Cetaphil',
    categorySlug: 'personal-care',
    categoryTitle: 'Personal Care',
    subcategoryLabel: 'Skin Care',
  ),
  Product(
    id: 'fake-minimalist',
    name: 'Minimalist SPF 50 Sunscreen',
    pack: 'Tube of 50 g',
    price: '350',
    mrp: '540',
    discountLabel: '35% OFF',
    icon: Icons.wb_sunny_outlined,
    brand: 'Minimalist',
    categorySlug: 'personal-care',
    categoryTitle: 'Personal Care',
    subcategoryLabel: 'Skin Care',
  ),
  Product(
    id: 'fake-dove',
    name: 'Dove Anti-Dandruff Shampoo',
    pack: 'Bottle of 340 ml',
    price: '360',
    mrp: '400',
    discountLabel: '10% OFF',
    icon: Icons.content_cut_rounded,
    brand: 'Dove',
    categorySlug: 'personal-care',
    categoryTitle: 'Personal Care',
    subcategoryLabel: 'Hair Care',
  ),
  Product(
    id: 'fake-bombay',
    name: 'Bombay Shaving Company Charcoal Face Wash',
    pack: 'Tube of 100 g',
    price: '199',
    mrp: '255',
    discountLabel: '22% OFF',
    icon: Icons.face_outlined,
    brand: 'Bombay Shaving Company',
    categorySlug: 'personal-care',
    categoryTitle: 'Personal Care',
    subcategoryLabel: 'Men Grooming',
  ),
  Product(
    id: 'fake-pears',
    name: 'Pears Pure & Gentle Body Wash',
    pack: 'Bottle of 250 ml',
    price: '210',
    mrp: '247',
    discountLabel: '15% OFF',
    icon: Icons.shower_outlined,
    brand: 'Pears',
    categorySlug: 'personal-care',
    categoryTitle: 'Personal Care',
    subcategoryLabel: 'Bath & Body',
  ),

  // ---- Health Conditions ----------------------------------------------
  Product(
    id: 'fake-dolo',
    name: 'Dolo 650mg Tablet',
    pack: 'Strip of 15 tablets',
    price: '32',
    mrp: '40',
    discountLabel: '20% OFF',
    icon: Icons.medication_outlined,
    brand: 'Micro Labs',
    categorySlug: 'health-conditions',
    categoryTitle: 'Health Conditions',
    subcategoryLabel: 'Pain Relief',
    isPopular: true,
  ),

  // ---- Vitamins & Supplements ---------------------------------------
  Product(
    id: 'fake-zincovit',
    name: 'Zincovit Multivitamin Tablet',
    pack: 'Bottle of 60 tablets',
    price: '90',
    mrp: '106',
    discountLabel: '15% OFF',
    icon: Icons.medication_liquid_outlined,
    brand: 'Apex Labs',
    categorySlug: 'vitamins-supplements',
    categoryTitle: 'Vitamins & Supplements',
    subcategoryLabel: 'Multivitamins',
    isPopular: true,
  ),
  Product(
    id: 'fake-immunity',
    name: 'SHIELD Immunity Plus',
    pack: 'Jar of 30 sachets',
    price: '400',
    mrp: '520',
    discountLabel: '23% OFF',
    icon: Icons.shield_outlined,
    categorySlug: 'vitamins-supplements',
    categoryTitle: 'Vitamins & Supplements',
    subcategoryLabel: 'Immunity',
  ),

  // ---- Diabetes Care ------------------------------------------------
  Product(
    id: 'fake-accuchek',
    name: 'Accu-Chek Test Strips',
    pack: 'Box of 50 strips',
    price: '899',
    mrp: '1299',
    discountLabel: '31% OFF',
    icon: Icons.receipt_long_outlined,
    brand: 'Roche',
    categorySlug: 'diabetes-care',
    categoryTitle: 'Diabetes Care',
    subcategoryLabel: 'Test Strips',
  ),

  // ---- Surgicals --------------------------------------------------
  Product(
    id: 'fake-gloves',
    name: 'Nitrile Examination Gloves',
    pack: 'Box of 100',
    price: '250',
    mrp: '300',
    discountLabel: '17% OFF',
    icon: Icons.masks_outlined,
    brand: 'Medline',
    categorySlug: 'surgicals',
    categoryTitle: 'Surgicals',
    subcategoryLabel: 'Gloves & Masks',
  ),

  // ---- Lab Tests ------------------------------------------------
  Product(
    id: 'fake-fullbody',
    name: 'Full Body Checkup Package',
    pack: '80 parameters',
    price: '999',
    mrp: '2499',
    discountLabel: '60% OFF',
    icon: Icons.fact_check_outlined,
    categorySlug: 'lab-tests',
    categoryTitle: 'Lab Tests',
    subcategoryLabel: 'Full Body Checkup',
  ),
];

/// Pushes [products] (the full [kFakeCatalogue] by default) into the live
/// [CatalogueService] so the screens under test have a catalogue to render.
void seedFakeCatalogue([List<Product> products = kFakeCatalogue]) {
  CatalogueService.instance.debugSeed(products);
}

/// Clears the seeded catalogue. Call in `tearDown`.
void resetFakeCatalogue() {
  CatalogueService.instance.debugReset();
}

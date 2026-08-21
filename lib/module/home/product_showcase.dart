import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../cart/cart_service.dart';

/// A titled, horizontally scrolling row of product cards.
///
/// Used for the "New on SHIELD", "Best Sellers" and "Deals of the Day"
/// strips on the home screen.
class ProductShowcase extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Product> products;

  const ProductShowcase({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            // Square artwork (the card's full width) plus the details block
            // below it.
            height: _ProductCard.width + _ProductCard.detailsExtent,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _ProductCard(product: products[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  static const double width = 162;

  /// Height reserved below the artwork for the name, pack, pricing and ADD.
  static const double detailsExtent = 140;

  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      // Clipped so a product image carrying its own fill cannot square off the
      // card's rounded corners now that the thumbnail panel is gone.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // No background of its own: the product sits directly on the
              // card's pure white surface. Square to match the artwork, which
              // a shorter box was letterboxing down to its own height.
              AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: product.image != null
                      ? const EdgeInsets.all(6)
                      : EdgeInsets.zero,
                  child: Center(
                    child: AppImage(
                      image: product.image,
                      fallbackIcon: product.icon,
                      iconSize: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (product.discountLabel != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreenDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.discountLabel!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.pack,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '₹${product.price}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '₹${product.mrp}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      // Open to everyone: the cart is built up freely and the
                      // account is only required at checkout.
                      onPressed: () {
                        CartService.instance.add(
                          name: product.name,
                          pack: product.pack,
                          // Fixtures carry formatted prices, so strip the
                          // grouping separator before parsing.
                          price:
                              double.tryParse(
                                product.price.replaceAll(',', ''),
                              ) ??
                              0,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            duration: const Duration(milliseconds: 1200),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandBlue,
                        side: const BorderSide(color: AppColors.brandBlue),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: const Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Product {
  final String name;
  final String pack;
  final String price;
  final String mrp;
  final String? discountLabel;
  final IconData icon;
  final String? image;

  const Product({
    required this.name,
    required this.pack,
    required this.price,
    required this.mrp,
    required this.icon,
    this.image,
    this.discountLabel,
  });
}

/// Fixture catalogues backing the three home showcases.
class ProductCatalogue {
  const ProductCatalogue._();

  static const List<Product> newArrivals = [
    Product(
      name: 'SHIELD Immunity Plus',
      pack: 'Bottle of 60 tablets',
      price: '449',
      mrp: '649',
      discountLabel: '31% OFF',
      icon: Icons.shield_outlined,
      image: 'assets/products/shield_immunity.png',
    ),
    Product(
      name: 'Omega-3 Fish Oil',
      pack: 'Bottle of 30 capsules',
      price: '389',
      mrp: '520',
      discountLabel: '25% OFF',
      icon: Icons.set_meal_outlined,
      image: 'assets/products/omega3_fish_oil.png',
    ),
    Product(
      name: 'Vitamin D3 60K',
      pack: 'Strip of 4 sachets',
      price: '128',
      mrp: '175',
      discountLabel: '27% OFF',
      icon: Icons.wb_sunny_outlined,
      image: 'assets/products/vitamin_d3.png',
    ),
    Product(
      name: 'Digital BP Monitor',
      pack: '1 device',
      price: '1,749',
      mrp: '2,499',
      discountLabel: '30% OFF',
      icon: Icons.monitor_heart_outlined,
      image: 'assets/products/bp_monitor.png',
    ),
  ];

  static const List<Product> bestSellers = [
    Product(
      name: 'Dolo 650mg Tablet',
      pack: 'Strip of 15 tablets',
      price: '32',
      mrp: '35',
      icon: Icons.medication_outlined,
      image: 'assets/products/dolo_650.png',
    ),
    Product(
      name: 'Shelcal 500 Calcium',
      pack: 'Strip of 15 tablets',
      price: '118',
      mrp: '145',
      discountLabel: '19% OFF',
      icon: Icons.emoji_food_beverage_outlined,
      image: 'assets/products/shelcal_500.png',
    ),
    Product(
      name: 'Zincovit Multivitamin',
      pack: 'Strip of 15 tablets',
      price: '106',
      mrp: '132',
      discountLabel: '20% OFF',
      icon: Icons.medication_liquid_outlined,
      image: 'assets/products/zincovit.png',
    ),
    Product(
      name: 'Volini Pain Relief Gel',
      pack: 'Tube of 30g',
      price: '148',
      mrp: '195',
      discountLabel: '24% OFF',
      icon: Icons.healing_outlined,
      image: 'assets/products/volini_gel.png',
    ),
  ];

  static const List<Product> dealsOfTheDay = [
    Product(
      name: 'Accu-Chek Test Strips',
      pack: 'Box of 50 strips',
      price: '899',
      mrp: '1,399',
      discountLabel: '36% OFF',
      icon: Icons.receipt_long_outlined,
      image: 'assets/products/accuchek_strips.png',
    ),
    Product(
      name: 'Protein Powder Chocolate',
      pack: 'Jar of 1kg',
      price: '1,999',
      mrp: '3,200',
      discountLabel: '38% OFF',
      icon: Icons.fitness_center_rounded,
      image: 'assets/products/protein_powder.png',
    ),
    Product(
      name: 'Digital Thermometer',
      pack: '1 device',
      price: '199',
      mrp: '349',
      discountLabel: '43% OFF',
      icon: Icons.thermostat_rounded,
    ),
    Product(
      name: 'Hand Sanitizer 500ml',
      pack: 'Bottle of 500ml',
      price: '149',
      mrp: '260',
      discountLabel: '42% OFF',
      icon: Icons.clean_hands_outlined,
    ),
  ];

  static const List<Product> vitamins = [
    Product(
      name: 'Zincovit Multivitamin',
      pack: 'Strip of 15 tablets',
      price: '106',
      mrp: '132',
      discountLabel: '20% OFF',
      icon: Icons.medication_liquid_outlined,
      image: 'assets/products/zincovit.png',
    ),
    Product(
      name: 'Vitamin D3 60K',
      pack: 'Strip of 4 sachets',
      price: '128',
      mrp: '175',
      discountLabel: '27% OFF',
      icon: Icons.wb_sunny_outlined,
      image: 'assets/products/vitamin_d3.png',
    ),
    Product(
      name: 'Omega-3 Fish Oil',
      pack: 'Bottle of 30 capsules',
      price: '389',
      mrp: '520',
      discountLabel: '25% OFF',
      icon: Icons.set_meal_outlined,
      image: 'assets/products/omega3_fish_oil.png',
    ),
    Product(
      name: 'Shelcal 500 Calcium',
      pack: 'Strip of 15 tablets',
      price: '118',
      mrp: '145',
      discountLabel: '19% OFF',
      icon: Icons.emoji_food_beverage_outlined,
      image: 'assets/products/shelcal_500.png',
    ),
    Product(
      name: 'Protein Powder Chocolate',
      pack: 'Jar of 1kg',
      price: '1,999',
      mrp: '3,200',
      discountLabel: '38% OFF',
      icon: Icons.fitness_center_rounded,
      image: 'assets/products/protein_powder.png',
    ),
    Product(
      name: 'SHIELD Immunity Plus',
      pack: 'Bottle of 60 tablets',
      price: '449',
      mrp: '649',
      discountLabel: '31% OFF',
      icon: Icons.shield_outlined,
      image: 'assets/products/shield_immunity.png',
    ),
  ];

  static const List<Product> diabetesCare = [
    Product(
      name: 'Accu-Chek Test Strips',
      pack: 'Box of 50 strips',
      price: '899',
      mrp: '1,399',
      discountLabel: '36% OFF',
      icon: Icons.receipt_long_outlined,
      image: 'assets/products/accuchek_strips.png',
    ),
    Product(
      name: 'Digital BP Monitor',
      pack: '1 device',
      price: '1,749',
      mrp: '2,499',
      discountLabel: '30% OFF',
      icon: Icons.monitor_heart_outlined,
      image: 'assets/products/bp_monitor.png',
    ),
    Product(
      name: 'Sugar Free Natura',
      pack: 'Jar of 500 pellets',
      price: '199',
      mrp: '260',
      discountLabel: '23% OFF',
      icon: Icons.coffee_outlined,
    ),
    Product(
      name: 'Diabetic Foot Cream',
      pack: 'Tube of 50g',
      price: '245',
      mrp: '340',
      discountLabel: '27% OFF',
      icon: Icons.healing_outlined,
    ),
  ];

  static const List<Product> healthConditions = [
    Product(
      name: 'Dolo 650mg Tablet',
      pack: 'Strip of 15 tablets',
      price: '32',
      mrp: '35',
      icon: Icons.medication_outlined,
      image: 'assets/products/dolo_650.png',
    ),
    Product(
      name: 'Volini Pain Relief Gel',
      pack: 'Tube of 30g',
      price: '148',
      mrp: '195',
      discountLabel: '24% OFF',
      icon: Icons.healing_outlined,
      image: 'assets/products/volini_gel.png',
    ),
    Product(
      name: 'Digene Acidity Relief',
      pack: 'Bottle of 200ml',
      price: '138',
      mrp: '175',
      discountLabel: '21% OFF',
      icon: Icons.local_dining_outlined,
    ),
    Product(
      name: 'Refresh Tears Eye Drops',
      pack: 'Bottle of 10ml',
      price: '128',
      mrp: '160',
      discountLabel: '20% OFF',
      icon: Icons.remove_red_eye_outlined,
    ),
  ];
}

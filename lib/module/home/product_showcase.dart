import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../cart/cart_control.dart';
import '../product/product_detail_screen.dart';
import 'product_collection_screen.dart';

/// A titled, horizontally scrolling row of product cards.
class ProductShowcase extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Product> products;
  final VoidCallback? onViewAll;

  const ProductShowcase({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
    this.onViewAll,
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
                  onPressed:
                      onViewAll ??
                      () {
                        // Straight to this row's own products, laid out as a
                        // full grid — not the generic category browser.
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductCollectionScreen(
                              title: title,
                              subtitle: subtitle,
                              products: products,
                            ),
                          ),
                        );
                      },
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

  /// Height reserved below the artwork for the name, pack, pricing and the
  /// 40px ADD / quantity control.
  static const double detailsExtent = 148;

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
      // The whole card opens the details page; the ADD / quantity control on
      // top keeps its own taps, so a shopper still adds without leaving.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
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
                      // Same control as the category listing: ADD, then an inline
                      // quantity stepper backed by the shared cart.
                      CartControl(
                        name: product.name,
                        pack: product.pack,
                        price: product.price,
                        mrp: product.mrp,
                        image: product.image,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

/// Product catalogues backing the home showcases.
class ProductCatalogue {
  const ProductCatalogue._();

  static const List<Product> popularItems = [
    Product(
      name: 'Dolo 650mg Tablet',
      pack: 'Strip of 15 tablets',
      price: '32',
      mrp: '35',
      discountLabel: '10% OFF',
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
      name: 'Volini Pain Relief Gel',
      pack: 'Tube of 30g',
      price: '148',
      mrp: '195',
      discountLabel: '24% OFF',
      icon: Icons.healing_outlined,
      image: 'assets/products/volini_gel.png',
    ),
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
      name: 'Cetaphil Pro Oil Control',
      pack: 'Bottle of 125ml',
      price: '890',
      mrp: '1,099',
      discountLabel: '19% OFF',
      icon: Icons.clean_hands_outlined,
      image: 'assets/products/cetaphil_pro_oil.png',
    ),
  ];

  static const List<Product> dealsYouLove = [
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
      name: 'Accu-Chek Test Strips',
      pack: 'Box of 50 strips',
      price: '899',
      mrp: '1,399',
      discountLabel: '36% OFF',
      icon: Icons.receipt_long_outlined,
      image: 'assets/products/accuchek_strips.png',
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
      name: 'SunShade Matte Gel',
      pack: 'Tube of 50g',
      price: '420',
      mrp: '550',
      discountLabel: '24% OFF',
      icon: Icons.wb_sunny_outlined,
      image: 'assets/products/sunshade_matte.png',
    ),
    Product(
      name: 'Soft Soles Foot Cream',
      pack: 'Tube of 50g',
      price: '165',
      mrp: '220',
      discountLabel: '25% OFF',
      icon: Icons.spa_outlined,
      image: 'assets/products/soft_soles_cream.png',
    ),
  ];

  static const List<Product> wellnessAndSupplements = [
    // The own brand leads the row.
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
  ];

  static const List<Product> wellness = wellnessAndSupplements;
}

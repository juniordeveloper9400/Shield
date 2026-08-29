import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A written review left by a customer.
class Testimonial {
  final String name;
  final String location;
  final String posted;
  final int rating;
  final String body;

  const Testimonial({
    required this.name,
    required this.location,
    required this.posted,
    required this.rating,
    required this.body,
  });

  /// One or two letters for the disc beside the review.
  ///
  /// Initials rather than a photograph: a stock face next to a written review
  /// implies the review came with a picture of the person who left it, and
  /// none of these did.
  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

/// "What our customers have to say" — an aggregate rating with the star
/// breakdown, followed by the written reviews behind it.
class CustomerTestimonials extends StatelessWidget {
  const CustomerTestimonials({super.key});

  static const String score = '4.8';
  static const int totalRatings = 5610;

  /// Share of ratings at each star level, five stars first.
  static const List<double> distribution = [0.82, 0.11, 0.04, 0.02, 0.01];

  static const List<Testimonial> testimonials = [
    Testimonial(
      name: 'Anjali Sharma',
      location: 'Mumbai',
      posted: '2 weeks ago',
      rating: 5,
      body:
          'Ordered my monthly medicines and saved almost half the price. '
          'Delivery reached in two days and everything was sealed properly.',
    ),
    Testimonial(
      name: 'Prakash Menon',
      location: 'Kochi',
      posted: '1 month ago',
      rating: 5,
      body:
          'The branded substitute suggestion saved me ₹1,200 on my father\'s '
          'BP medication. Same composition, much lower cost.',
    ),
    Testimonial(
      name: 'Ritu Kapoor',
      location: 'Delhi',
      posted: '1 month ago',
      rating: 4,
      body:
          'Uploading the prescription was simple and the pharmacist called to '
          'confirm the dosage before shipping. Very reassuring.',
    ),
    Testimonial(
      name: 'Suresh Nair',
      location: 'Bengaluru',
      posted: '2 months ago',
      rating: 5,
      body:
          'Wallet cashback actually works. Six months in and the savings '
          'genuinely add up every single month.',
    ),
    Testimonial(
      name: 'Vandana Joshi',
      location: 'Pune',
      posted: '3 months ago',
      rating: 5,
      body:
          'Great range of supplements and the refill reminders keep me on '
          'track. Support replied within minutes when I had a query.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageTint,
      padding: const EdgeInsets.only(top: 22, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            // The video reel higher up the feed already carries "What our
            // customers have to say"; this block is the written-review and
            // rating view of the same thing, so it takes its own heading
            // rather than repeating that one.
            child: Text(
              'Ratings & Reviews',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _RatingSummaryCard(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: testimonials.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _TestimonialCard(testimonial: testimonials[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                CustomerTestimonials.score,
                style: TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const _Stars(rating: 5, size: 16),
              const SizedBox(height: 6),
              Text(
                '${CustomerTestimonials.totalRatings} ratings',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var i = 0;
                  i < CustomerTestimonials.distribution.length;
                  i++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: _DistributionRow(
                      stars: 5 - i,
                      fraction: CustomerTestimonials.distribution[i],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final int stars;
  final double fraction;

  const _DistributionRow({required this.stars, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(
            '$stars',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A623)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF5A623)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final Testimonial testimonial;

  const _TestimonialCard({required this.testimonial});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 274,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _InitialsDisc(initials: testimonial.initials),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimonial.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${testimonial.location} · ${testimonial.posted}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Stars(rating: testimonial.rating, size: 15),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                testimonial.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textBody,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: AppColors.brandGreenDeep,
                ),
                SizedBox(width: 5),
                Text(
                  'Verified purchase',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandGreenDeep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;
  final double size;

  const _Stars({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xFFF5A623),
          ),
      ],
    );
  }
}

/// The reviewer's initials, in the brand's blue.
class _InitialsDisc extends StatelessWidget {
  final String initials;

  const _InitialsDisc({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.categoryPanel,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.brandBlue,
        ),
      ),
    );
  }
}

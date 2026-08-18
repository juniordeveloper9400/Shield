import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "What our customers say" — a horizontally scrolling wall of reviews, each
/// with a photo, star rating, and verified-purchase marker.
class CustomerReviews extends StatelessWidget {
  const CustomerReviews({super.key});

  static const List<_Review> _reviews = [
    _Review(
      name: 'Anjali Sharma',
      location: 'Mumbai, MH',
      avatar: 'assets/avatars/avatar_1.png',
      rating: 5,
      body:
          'Ordered my monthly medicines and saved almost half the price. '
          'Delivery reached in two days and everything was sealed properly.',
    ),
    _Review(
      name: 'Prakash Menon',
      location: 'Kochi, KL',
      avatar: 'assets/avatars/avatar_2.png',
      rating: 5,
      body:
          'The branded substitute suggestion saved me ₹1,200 on my father\'s '
          'BP medication. Same composition, same effect, much lower cost.',
    ),
    _Review(
      name: 'Ritu Kapoor',
      location: 'Delhi, DL',
      avatar: 'assets/avatars/avatar_3.png',
      rating: 4,
      body:
          'Uploading the prescription was simple and the pharmacist called to '
          'confirm the dosage before shipping. Very reassuring service.',
    ),
    _Review(
      name: 'Suresh Nair',
      location: 'Bengaluru, KA',
      avatar: 'assets/avatars/avatar_4.png',
      rating: 5,
      body:
          'Wallet cashback actually works. I have been using SHIELD for six '
          'months now and the savings genuinely add up every month.',
    ),
    _Review(
      name: 'Vandana Joshi',
      location: 'Pune, MH',
      avatar: 'assets/avatars/avatar_5.png',
      rating: 5,
      body:
          'Great range of supplements and the reminders help me stay on track. '
          'Customer support responded within minutes when I had a query.',
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
            padding: EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              'What our customers say',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _RatingSummary(),
          ),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _reviews.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _ReviewCard(review: _reviews[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Stars(rating: 5, size: 17),
        const SizedBox(width: 7),
        const Text(
          '4.8',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'from 5.61L verified customers',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
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
              ClipOval(
                child: Image.asset(
                  review.avatar,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
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
                      review.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stars(rating: review.rating, size: 16),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              review.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textBody,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 15,
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

class _Review {
  final String name;
  final String location;
  final String avatar;
  final int rating;
  final String body;

  const _Review({
    required this.name,
    required this.location,
    required this.avatar,
    required this.rating,
    required this.body,
  });
}

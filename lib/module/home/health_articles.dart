import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// One editorial piece in the health library.
class HealthArticle {
  final String title;
  final String topic;
  final String readTime;
  final IconData icon;
  final Color tint;

  const HealthArticle({
    required this.title,
    required this.topic,
    required this.readTime,
    required this.icon,
    required this.tint,
  });
}

/// "Health Articles" — a scrolling row of editorial cards.
class HealthArticlesSection extends StatelessWidget {
  const HealthArticlesSection({super.key});

  static const List<HealthArticle> articles = [
    HealthArticle(
      title: 'Five everyday habits that keep blood sugar steady',
      topic: 'Diabetes',
      readTime: '4 min read',
      icon: Icons.bloodtype_outlined,
      tint: AppColors.panelPink,
    ),
    HealthArticle(
      title: 'How to read a vitamin D report without guessing',
      topic: 'Nutrition',
      readTime: '6 min read',
      icon: Icons.wb_sunny_outlined,
      tint: AppColors.panelCream,
    ),
    HealthArticle(
      title: 'Branded substitutes: same molecule, lower price',
      topic: 'Medicines',
      readTime: '3 min read',
      icon: Icons.medication_outlined,
      tint: AppColors.panelBlue,
    ),
    HealthArticle(
      title: 'Joint pain in your thirties is not normal',
      topic: 'Bone & Joint',
      readTime: '5 min read',
      icon: Icons.accessibility_new_rounded,
      tint: AppColors.panelGreen,
    ),
    HealthArticle(
      title: 'What a full body checkup actually covers',
      topic: 'Lab Tests',
      readTime: '7 min read',
      icon: Icons.biotech_outlined,
      tint: AppColors.panelSlate,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 2),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Health Articles',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Written and reviewed by our clinical team',
              style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: articles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _ArticleCard(article: articles[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final HealthArticle article;

  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 218,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 74,
                  width: double.infinity,
                  color: article.tint,
                  alignment: Alignment.center,
                  child: Icon(
                    article.icon,
                    size: 32,
                    color: AppColors.brandBlue,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.topic.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandGreenDeep,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Expanded(
                          child: Text(
                            article.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                article.readTime,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

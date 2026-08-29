import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A titled block of body copy inside an article.
class ArticleSection {
  final String heading;
  final List<String> paragraphs;

  const ArticleSection({required this.heading, required this.paragraphs});
}

/// One editorial piece in the health library.
class HealthArticle {
  final String title;

  /// Category labels shown as pill tags under the byline. The first also
  /// stands in as the card's kicker on the home strip.
  final List<String> topics;
  final String author;
  final String date;
  final String readTime;
  final IconData icon;
  final Color tint;

  /// The short headline set over the hero artwork, echoing the printed
  /// cover line on the reference design.
  final String heroKicker;

  /// Standfirst paragraphs shown above the table of contents.
  final List<String> intro;
  final List<ArticleSection> sections;

  const HealthArticle({
    required this.title,
    required this.topics,
    required this.author,
    required this.date,
    required this.readTime,
    required this.icon,
    required this.tint,
    required this.heroKicker,
    required this.intro,
    required this.sections,
  });

  String get topic => topics.first;
}

/// "Health Articles" — a scrolling row of editorial cards.
class HealthArticlesSection extends StatelessWidget {
  const HealthArticlesSection({super.key});

  static const List<HealthArticle> articles = [
    HealthArticle(
      title: 'How Pain Relief Medications Affect Liver and Kidney Health',
      topics: ['Disease Management', 'Health Conditions'],
      author: 'Amatul Ameen',
      date: '27 May 2026',
      readTime: '6 min read',
      icon: Icons.healing_rounded,
      tint: AppColors.panelBlue,
      heroKicker: 'Pain Relief & Its Impact on Liver and Kidneys',
      intro: [
        'Every year, tens of thousands of people are hospitalised for '
            'paracetamol-related liver injury, many of them unaware they had '
            'exceeded the safe dose. For a medicine sold in every pharmacy and '
            'often described as ‘the safest painkiller’, that '
            'statistic is worth pausing on. If used at higher than recommended '
            'doses, combined with alcohol, or taken alongside certain '
            'prescription medicines, these medicines can cause hepatotoxicity '
            '(liver cell death) or acute kidney injury, in some cases without '
            'warning symptoms.',
        'This article explains exactly how the most common over-the-counter '
            'pain medicines interact with your liver and kidneys, and when '
            'routine use tips into genuine risk.',
      ],
      sections: [
        ArticleSection(
          heading: 'How paracetamol is processed by the liver',
          paragraphs: [
            'At normal doses the liver clears paracetamol safely, converting '
                'most of it into harmless compounds that leave the body in '
                'urine. A small fraction becomes a reactive by-product called '
                'NAPQI, which the liver neutralises using its glutathione '
                'reserve.',
            'When the dose is too high, or glutathione is already depleted by '
                'fasting or regular alcohol use, NAPQI builds up and begins '
                'killing liver cells. Damage can be well advanced before '
                'nausea or abdominal pain appear, which is why dosing limits '
                'matter even when you feel fine.',
          ],
        ),
        ArticleSection(
          heading: 'Why NSAIDs put pressure on the kidneys',
          paragraphs: [
            'Ibuprofen, diclofenac and naproxen work by blocking '
                'prostaglandins, the same signalling molecules that help keep '
                'blood flowing through the kidneys. In a healthy, '
                'well-hydrated adult this rarely matters. During dehydration, '
                'illness, or alongside blood-pressure medication, that drop in '
                'flow can reduce filtration enough to cause acute kidney '
                'injury.',
            'The risk climbs with age, with existing kidney or heart disease, '
                'and with courses that run longer than about ten days. Taking '
                'the lowest dose that controls the pain, for the shortest '
                'time, keeps NSAIDs in their safe range for most people.',
          ],
        ),
        ArticleSection(
          heading: 'Safer everyday use',
          paragraphs: [
            'Keep total paracetamol under 3–4 g a day for an adult, and '
                'check combination cold-and-flu products so you do not double '
                'up without noticing. Avoid NSAIDs if you are dehydrated, '
                'pregnant in the third trimester, or on medicines for blood '
                'pressure, and take them with food.',
            'If you need a pain reliever most days for more than two weeks, '
                'that is a conversation with a doctor rather than a longer '
                'stint at the pharmacy shelf.',
          ],
        ),
      ],
    ),
    HealthArticle(
      title: 'Five everyday habits that keep blood sugar steady',
      topics: ['Diabetes', 'Lifestyle'],
      author: 'Dr. Neha Rao',
      date: '14 May 2026',
      readTime: '4 min read',
      icon: Icons.monitor_heart_outlined,
      tint: AppColors.panelPink,
      heroKicker: 'Small daily choices that flatten the curve',
      intro: [
        'Blood sugar does not swing on its own. It responds, hour by hour, to '
            'what you eat, how you move, and how well you slept. A handful of '
            'unremarkable habits, repeated, do more for a steady reading than '
            'any single dramatic change.',
      ],
      sections: [
        ArticleSection(
          heading: 'Walk after the largest meal',
          paragraphs: [
            'Ten to fifteen minutes of easy walking within half an hour of '
                'eating pulls glucose into working muscle and noticeably '
                'blunts the post-meal spike. It is the single highest-return '
                'habit on this list and needs no equipment.',
          ],
        ),
        ArticleSection(
          heading: 'Put protein and fibre first',
          paragraphs: [
            'Eating vegetables and a protein source before the starch on your '
                'plate slows how fast the meal is absorbed, so the same food '
                'produces a gentler rise.',
          ],
        ),
        ArticleSection(
          heading: 'Protect your sleep',
          paragraphs: [
            'A single short night raises next-day insulin resistance in '
                'healthy people. Consistent seven-to-eight-hour nights keep '
                'morning readings predictable.',
          ],
        ),
      ],
    ),
    HealthArticle(
      title: 'How to read a vitamin D report without guessing',
      topics: ['Nutrition', 'Lab Tests'],
      author: 'Dr. Imran Qureshi',
      date: '2 May 2026',
      readTime: '6 min read',
      icon: Icons.wb_sunny_outlined,
      tint: AppColors.panelCream,
      heroKicker: 'What the numbers on your vitamin D panel mean',
      intro: [
        'A vitamin D result is one number with a lot riding on it, and the '
            'reference ranges printed beside it are not as settled as they '
            'look. Here is how to place your value in context.',
      ],
      sections: [
        ArticleSection(
          heading: 'Which test you actually had',
          paragraphs: [
            'The standard test measures 25-hydroxyvitamin D, the storage form. '
                'The 1,25-dihydroxy test is a different measurement ordered for '
                'specific kidney and calcium problems, and a normal result '
                'there does not rule out deficiency.',
          ],
        ),
        ArticleSection(
          heading: 'Reading the range',
          paragraphs: [
            'Most labs flag below 20 ng/mL as deficient and 20–30 as '
                'insufficient. Values from 30 to 50 are comfortable for most '
                'adults. Above 100 is worth acting on, usually by stopping '
                'high-dose supplements.',
          ],
        ),
      ],
    ),
    HealthArticle(
      title: 'Branded substitutes: same molecule, lower price',
      topics: ['Medicines', 'Savings'],
      author: 'Sana Kapoor',
      date: '21 April 2026',
      readTime: '3 min read',
      icon: Icons.medication_outlined,
      tint: AppColors.panelBlue,
      heroKicker: 'How a generic can cost a fraction of the brand',
      intro: [
        'Two boxes on the same shelf can hold the identical active ingredient '
            'at the identical strength and differ four-fold in price. The gap '
            'is brand and packaging, not chemistry.',
      ],
      sections: [
        ArticleSection(
          heading: 'What "bioequivalent" guarantees',
          paragraphs: [
            'A licensed generic has been shown to deliver the same amount of '
                'drug into the bloodstream, at the same rate, as the original. '
                'That is the bar it must clear before it can be sold.',
          ],
        ),
        ArticleSection(
          heading: 'When to stay with one brand',
          paragraphs: [
            'For a few narrow-margin drugs — some thyroid, epilepsy and '
                'blood-thinning medicines — it is sensible to stick with '
                'one manufacturer once you are stable, and to tell your doctor '
                'if the supply changes.',
          ],
        ),
      ],
    ),
    HealthArticle(
      title: 'Joint pain in your thirties is not normal',
      topics: ['Bone & Joint', 'Health Conditions'],
      author: 'Dr. Kavya Menon',
      date: '9 April 2026',
      readTime: '5 min read',
      icon: Icons.accessibility_new_rounded,
      tint: AppColors.panelGreen,
      heroKicker: 'Early joint pain is a signal, not a life sentence',
      intro: [
        'Aching knees or stiff fingers at 35 are common, but common is not the '
            'same as expected. Persistent joint pain at that age usually has a '
            'specific, treatable cause worth naming.',
      ],
      sections: [
        ArticleSection(
          heading: 'Mechanical versus inflammatory',
          paragraphs: [
            'Pain that is worst after use and eases with rest points to a '
                'mechanical problem. Pain and stiffness that are worst in the '
                'morning, lasting more than an hour, point to inflammation and '
                'deserve a prompt review.',
          ],
        ),
        ArticleSection(
          heading: 'What helps early',
          paragraphs: [
            'Load management, targeted strengthening of the muscles around the '
                'joint, and keeping body weight in a healthy band change the '
                'long-term picture more than any supplement.',
          ],
        ),
      ],
    ),
    HealthArticle(
      title: 'What a full body checkup actually covers',
      topics: ['Lab Tests', 'Preventive Care'],
      author: 'Dr. Arjun Pillai',
      date: '28 March 2026',
      readTime: '7 min read',
      icon: Icons.biotech_outlined,
      tint: AppColors.panelSlate,
      heroKicker: 'Inside a routine full body health package',
      intro: [
        'A "full body" package is a bundle of standard blood and urine tests '
            'chosen to catch the common silent conditions. Knowing what is in '
            'it, and what is not, helps you read the report.',
      ],
      sections: [
        ArticleSection(
          heading: 'The core panels',
          paragraphs: [
            'Expect a complete blood count, fasting glucose and HbA1c, a lipid '
                'profile, liver and kidney function, thyroid-stimulating '
                'hormone, and a urine routine. Together these screen for '
                'anaemia, diabetes, cholesterol, organ strain and thyroid '
                'imbalance.',
          ],
        ),
        ArticleSection(
          heading: 'What it will not tell you',
          paragraphs: [
            'A standard package does not image your heart or scan for most '
                'cancers. Symptoms in those areas still need their own '
                'targeted tests rather than a repeat of the bundle.',
          ],
        ),
      ],
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

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthArticleScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 218,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _open(context),
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

/// The full read for a single [HealthArticle], opened from the home strip.
///
/// Laid out to match the reference design: a captioned hero, the title and
/// byline, the category tags, a standfirst, then a table of contents over the
/// numbered body sections.
class HealthArticleScreen extends StatelessWidget {
  final HealthArticle article;

  const HealthArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Health Articles',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ArticleHero(article: article),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 14),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      const TextSpan(text: 'By '),
                      TextSpan(
                        text: article.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBody,
                        ),
                      ),
                      TextSpan(text: '  ${article.date}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final topic in article.topics) _TagChip(label: topic),
                  ],
                ),
                const SizedBox(height: 22),
                for (final paragraph in article.intro) ...[
                  Text(
                    paragraph,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.6,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 6),
                _TableOfContents(sections: article.sections),
                const SizedBox(height: 8),
                for (var i = 0; i < article.sections.length; i++)
                  _SectionBlock(
                    number: i + 1,
                    section: article.sections[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleHero extends StatelessWidget {
  final HealthArticle article;

  const _ArticleHero({required this.article});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: article.tint),
          ),
          Positioned(
            left: -18,
            bottom: -20,
            child: Icon(
              article.icon,
              size: 190,
              color: AppColors.brandBlue.withValues(alpha: 0.14),
            ),
          ),
          // The blue "cover line" tab, echoing the printed shield on the
          // reference artwork.
          Positioned(
            top: 0,
            right: 24,
            child: Container(
              width: 176,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
              decoration: const BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(38),
                ),
              ),
              child: Text(
                article.heroKicker,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logos/shield_wordmark.png',
                height: 16,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.brandGreenDeep,
        ),
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  final List<ArticleSection> sections;

  const _TableOfContents({required this.sections});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.pageTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Table of Contents',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sections[i].heading,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: AppColors.textBody,
                      ),
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

class _SectionBlock extends StatelessWidget {
  final int number;
  final ArticleSection section;

  const _SectionBlock({required this.number, required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${section.heading}',
            style: const TextStyle(
              fontSize: 18.5,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < section.paragraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: Text(
                section.paragraphs[i],
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.6,
                  color: AppColors.textBody,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

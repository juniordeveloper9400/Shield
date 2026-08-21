import 'dart:async';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Customer video review item model.
class CustomerReviewItem {
  final String id;
  final String name;
  final String fullName;
  final String location;
  final String avatar;
  final int rating;
  final String subtitle;
  final String fullReview;
  final Duration duration;

  const CustomerReviewItem({
    required this.id,
    required this.name,
    required this.fullName,
    required this.location,
    required this.avatar,
    required this.rating,
    required this.subtitle,
    required this.fullReview,
    this.duration = const Duration(seconds: 8),
  });
}

/// "What our customers have to say" — interactive customer video review reel
/// section displayed directly under the offer banner.
class CustomerReviews extends StatelessWidget {
  const CustomerReviews({super.key});

  static const List<CustomerReviewItem> reviews = [
    CustomerReviewItem(
      id: 'jai',
      name: 'Jai',
      fullName: 'Jai Sharma',
      location: 'Kolkata, WB',
      avatar: 'assets/avatars/avatar_1.png',
      rating: 5,
      subtitle:
          'basically main belong\nKolkata se karta hoon\n\nSHIELD se regular medicines order karta hoon, delivery always super fast!',
      fullReview:
          'Ordered my monthly medicines and saved almost half the price. Delivery reached in two days and everything was sealed properly with batch verification.',
    ),
    CustomerReviewItem(
      id: 'srishti',
      name: 'Srishti',
      fullName: 'Srishti Menon',
      location: 'Mumbai, MH',
      avatar: 'assets/avatars/avatar_2.png',
      rating: 5,
      subtitle:
          'Maine supplements order kiye the.\nQuality and packaging both are top notch!',
      fullReview:
          'Great range of wellness supplements and genuine medicines. Customer support responded within minutes when I needed to update my delivery address.',
    ),
    CustomerReviewItem(
      id: 'anil',
      name: 'Anil',
      fullName: 'Anil Kapoor',
      location: 'Delhi, DL',
      avatar: 'assets/avatars/avatar_3.png',
      rating: 5,
      subtitle:
          'My regular BP medicines arrive right on time.\nSaved over ₹1,200 every month!',
      fullReview:
          'The branded substitute suggestion saved me ₹1,200 on my regular BP medication. Same composition, same effect, much lower cost.',
    ),
    CustomerReviewItem(
      id: 'anjali',
      name: 'Anjali',
      fullName: 'Anjali Sharma',
      location: 'Bengaluru, KA',
      avatar: 'assets/avatars/avatar_4.png',
      rating: 5,
      subtitle:
          'Prescription upload karna bahut simple tha.\nPharmacist ne call karke confirm kiya!',
      fullReview:
          'Uploading the prescription was seamless and the verified pharmacist called to double-check dosage before dispatch. Very reassuring service.',
    ),
    CustomerReviewItem(
      id: 'vandana',
      name: 'Vandana',
      fullName: 'Vandana Joshi',
      location: 'Pune, MH',
      avatar: 'assets/avatars/avatar_5.png',
      rating: 5,
      subtitle:
          'Cashback and refill reminders really help.\nReliable and trustworthy service!',
      fullReview:
          'Wallet cashback actually works. I have been using SHIELD for six months now and the monthly savings genuinely add up.',
    ),
  ];

  void _openStoryViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: CustomerStoryPlayerModal(
              reviews: reviews,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(top: 14, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'What our customers have to say',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(
            height: 242,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _VideoReviewThumbnailCard(
                  review: review,
                  onTap: () => _openStoryViewer(context, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Video Review Thumbnail Card matching Screenshot 1.
class _VideoReviewThumbnailCard extends StatelessWidget {
  final CustomerReviewItem review;
  final VoidCallback onTap;

  const _VideoReviewThumbnailCard({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 142,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Portrait photo of customer
              Image.asset(
                review.avatar,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.bannerTop,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),

              // Gradient overlay from top (dark for name) to bottom
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                    ],
                    stops: const [0.0, 0.40, 1.0],
                  ),
                ),
              ),

              // Reviewer First Name on Top Left (as in Screenshot 1)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Text(
                  review.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
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

/// Fullscreen Story / Customer Video Review Player matching Screenshot 2.
class CustomerStoryPlayerModal extends StatefulWidget {
  final List<CustomerReviewItem> reviews;
  final int initialIndex;

  const CustomerStoryPlayerModal({
    super.key,
    required this.reviews,
    this.initialIndex = 0,
  });

  @override
  State<CustomerStoryPlayerModal> createState() =>
      _CustomerStoryPlayerModalState();
}

class _CustomerStoryPlayerModalState extends State<CustomerStoryPlayerModal>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animController;
  bool _isPlaying = true;
  bool _isMuted = false;
  Timer? _ticker;
  double _currentSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _animController = AnimationController(
      vsync: this,
      duration: widget.reviews[_currentIndex].duration,
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryFinished();
      }
    });

    _animController.addListener(() {
      setState(() {
        _currentSeconds =
            _animController.value *
            widget.reviews[_currentIndex].duration.inSeconds;
      });
    });

    _startCurrentStory();
  }

  void _startCurrentStory() {
    _animController.duration = widget.reviews[_currentIndex].duration;
    _animController.reset();
    if (_isPlaying) {
      _animController.forward();
    }
  }

  void _onStoryFinished() {
    if (_currentIndex < widget.reviews.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startCurrentStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPrevious() {
    if (_animController.value > 0.25 || _currentIndex == 0) {
      _startCurrentStory();
    } else {
      setState(() {
        _currentIndex--;
      });
      _startCurrentStory();
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.reviews.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startCurrentStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _animController.forward();
      } else {
        _animController.stop();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _seekTo(double value) {
    setState(() {
      _animController.value = value.clamp(0.0, 1.0);
      _currentSeconds =
          _animController.value *
          widget.reviews[_currentIndex].duration.inSeconds;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _formatTime(double seconds) {
    final int s = seconds.floor();
    final int mins = s ~/ 60;
    final int remSecs = s % 60;
    return '${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentReview = widget.reviews[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              Navigator.of(context).pop();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Video Content / Visual Frame
              Center(
                child: Image.asset(
                  currentReview.avatar,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 80,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),

              // Gradient overlays for crisp contrast on text and controls
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.70),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.30, 1.0],
                    ),
                  ),
                ),
              ),

              // Tap zones: left to go back, right to go next, hold to pause
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _goToPrevious,
                        onLongPressStart: (_) {
                          if (_isPlaying) _animController.stop();
                        },
                        onLongPressEnd: (_) {
                          if (_isPlaying) _animController.forward();
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _goToNext,
                        onLongPressStart: (_) {
                          if (_isPlaying) _animController.stop();
                        },
                        onLongPressEnd: (_) {
                          if (_isPlaying) _animController.forward();
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),

              // Subtitles / Captions in center-bottom matching Screenshot 2
              Positioned(
                left: 24,
                right: 24,
                bottom: 96,
                child: IgnorePointer(
                  child: Text(
                    currentReview.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Top Section: Story Progress Indicators & Header Row
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Segmented Progress Bars
                    Row(
                      children: List.generate(widget.reviews.length, (index) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                double fillFraction = 0.0;
                                if (index < _currentIndex) {
                                  fillFraction = 1.0;
                                } else if (index == _currentIndex) {
                                  fillFraction = _animController.value;
                                }
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: constraints.maxWidth * fillFraction,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Header Row: Reviewer name on left, Close icon on right
                    Row(
                      children: [
                        Text(
                          currentReview.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Control Bar matching Screenshot 2 (Play/Pause, Slider, Time, Audio)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      // Play / Pause Button
                      IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: _togglePlayPause,
                      ),

                      // Timeline scrubber
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _animController.value.clamp(0.0, 1.0),
                            onChanged: (val) {
                              _animController.stop();
                              _seekTo(val);
                            },
                            onChangeEnd: (val) {
                              if (_isPlaying) {
                                _animController.forward();
                              }
                            },
                          ),
                        ),
                      ),

                      // Time Display (e.g. 00:02)
                      Text(
                        _formatTime(_currentSeconds),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Mute / Unmute Button
                      IconButton(
                        icon: Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: _toggleMute,
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

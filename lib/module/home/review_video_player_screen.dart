import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Full-screen page for a customer review clip that's a YouTube link —
/// opened instead of [CustomerStoryPlayerModal] for that case, since a
/// YouTube video plays through YouTube's own embedded player (native
/// controls, fullscreen, captions) rather than the story reel's custom
/// swipe/scrub controls, which only drive `video_player`.
class ReviewVideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String? description;

  const ReviewVideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    this.description,
  });

  @override
  State<ReviewVideoPlayerScreen> createState() =>
      _ReviewVideoPlayerScreenState();
}

class _ReviewVideoPlayerScreenState extends State<ReviewVideoPlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Review')),
      body: ListView(
        children: [
          YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 8),
                  Text(widget.description!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

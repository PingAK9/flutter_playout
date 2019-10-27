import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_playout/player_state.dart';

/// Video plugin for playing HLS stream using native player. [autoPlay] flag
/// controls whether to start playback as soon as player is ready. The [title]
/// and [subtitle] are used for lock screen info panel on both iOS & Android.
/// The [isLiveStream] flag is only used on iOS to change the scrub-bar look
/// on lock screen info panel. It has no affect on the actual functionality
/// of the plugin. Defaults to false. Use [onViewCreated] callback to get
/// notified once the underlying [PlatformView] is setup.
/// The [desiredState] enum can be used to control play/pause. If the value
/// change, the widget will make sure that player is in sync with the new state.
class Video extends StatefulWidget {
  final bool autoPlay;
  final String url;
  final String title;
  final String subtitle;
  final bool isLiveStream;
  final Function onViewCreated;
  final PlayerState desiredState;

  const Video(
      {Key key,
      this.autoPlay = false,
      this.url,
      this.title = "",
      this.subtitle = "",
      this.isLiveStream = false,
      this.onViewCreated,
      this.desiredState = PlayerState.PLAYING})
      : super(key: key);

  @override
  _VideoState createState() => _VideoState();
}

class _VideoState extends State<Video> {
  MethodChannel _methodChannel;

  @override
  Widget build(BuildContext context) {
    Widget playerWidget = Container();

    /* setup player */
    if (widget.url != null && widget.url.isNotEmpty) {
      /* Android */
      if (Platform.isAndroid) {
        playerWidget = AndroidView(
          viewType: 'tv.mta/NativeVideoPlayer',
          creationParams: {
            "autoPlay": widget.autoPlay,
            "url": widget.url,
            "title": widget.title ?? "",
            "subtitle": widget.subtitle ?? "",
            "isLiveStream": widget.isLiveStream,
          },
          creationParamsCodec: const JSONMessageCodec(),
          onPlatformViewCreated: (viewId) {
            _onPlatformViewCreated(viewId);
            if (widget.onViewCreated != null) {
              widget.onViewCreated(viewId);
            }
          },
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
            new Factory<OneSequenceGestureRecognizer>(
              () => new EagerGestureRecognizer(),
            ),
          ].toSet(),
        );
      }

      /* iOS */
      else if (Platform.isIOS) {
        playerWidget = UiKitView(
          viewType: 'tv.mta/NativeVideoPlayer',
          creationParams: {
            "autoPlay": widget.autoPlay,
            "url": widget.url,
            "title": widget.title ?? "",
            "subtitle": widget.subtitle ?? "",
            "isLiveStream": widget.isLiveStream,
          },
          creationParamsCodec: const JSONMessageCodec(),
          onPlatformViewCreated: (viewId) {
            _onPlatformViewCreated(viewId);
            if (widget.onViewCreated != null) {
              widget.onViewCreated(viewId);
            }
          },
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
            new Factory<OneSequenceGestureRecognizer>(
              () => new EagerGestureRecognizer(),
            ),
          ].toSet(),
        );
      }
    } else {
      _disposePlatformView();
    }

    return GestureDetector(
      onTap: () {},
      child: playerWidget,
    );
  }

  @override
  void didUpdateWidget(Video oldWidget) {
    if (oldWidget.url != widget.url ||
        oldWidget.title != widget.title ||
        oldWidget.subtitle != widget.subtitle ||
        oldWidget.isLiveStream != widget.isLiveStream) {
      _onMediaChanged();
    }
    if (oldWidget.desiredState != widget.desiredState) {
      _onDesiredStateChanged(oldWidget);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _disposePlatformView(isDisposing: true);
    super.dispose();
  }

  void _onPlatformViewCreated(int viewId) {
    _methodChannel =
        MethodChannel("tv.mta/NativeVideoPlayerMethodChannel_$viewId");
  }

  /// The [desiredState] flag has changed so need to update playback to
  /// reflect the new state.
  void _onDesiredStateChanged(Video oldWidget) async {
    switch (widget.desiredState) {
      case PlayerState.PLAYING:
        _resumePlayback();
        break;
      case PlayerState.PAUSED:
        _pausePlayback();
        break;
      case PlayerState.STOPPED:
        _pausePlayback();
        break;
    }
  }

  void _pausePlayback() async {
    if (_methodChannel != null) {
      _methodChannel.invokeMethod("pause");
    }
  }

  void _resumePlayback() async {
    if (_methodChannel != null) {
      _methodChannel.invokeMethod("resume");
    }
  }

  void _onMediaChanged() {
    if (widget.url != null && _methodChannel != null) {
      _methodChannel.invokeMethod("onMediaChanged", {
        "autoPlay": widget.autoPlay,
        "url": widget.url,
        "title": widget.title,
        "subtitle": widget.subtitle,
        "isLiveStream": widget.isLiveStream,
      });
    }
  }

  void _disposePlatformView({bool isDisposing = false}) {
    if (_methodChannel != null) {
      /* clean platform view */
      _methodChannel.invokeMethod("dispose");

      if (!isDisposing) {
        setState(() {
          _methodChannel = null;
        });
      }
    }
  }
}

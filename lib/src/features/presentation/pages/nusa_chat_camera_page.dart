import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// The in-app camera, used instead of the OS camera app so the flow stays in
/// the chat (same approach as nusa_selecta's `CameraPage`). Pops with the
/// photo's path; the chat then opens its image preview, where the photo can
/// be captioned, deleted or joined by more.
///
/// Needs the camera permission: `android.permission.CAMERA` and
/// `NSCameraUsageDescription` in the host app.
class NusaChatCameraPage extends StatefulWidget {
  final NusaChatStrings strings;

  const NusaChatCameraPage({super.key, this.strings = const NusaChatStrings()});

  @override
  State<NusaChatCameraPage> createState() => _NusaChatCameraPageState();
}

class _NusaChatCameraPageState extends State<NusaChatCameraPage> with WidgetsBindingObserver {
  static const List<FlashMode> _flashModes = [FlashMode.off, FlashMode.torch];

  final ValueNotifier<double> _zoomLevel = ValueNotifier<double>(1);

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isTakingPicture = false;
  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  FlashMode _selectedFlashMode = FlashMode.off;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _zoomLevel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _cameraController = null;
      setState(() => _isCameraInitialized = false);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _initCamera(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
    } on CameraException {
      _cameras = [];
    }
    if (_cameras.isEmpty) {
      _close(widget.strings.cameraUnavailable);
      return;
    }
    final back = _cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.back);
    _selectedCameraIndex = back < 0 ? 0 : back;
    await _initCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _initCamera(CameraDescription description) async {
    final previous = _cameraController;
    if (previous != null) {
      _cameraController = null;
      if (mounted) setState(() => _isCameraInitialized = false);
      await previous.dispose();
    }

    final controller = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController = controller;

    try {
      await controller.initialize();
      _maxZoomLevel = await controller.getMaxZoomLevel();
      _minZoomLevel = await controller.getMinZoomLevel();
      _zoomLevel.value = _minZoomLevel;
      await controller.setFlashMode(_selectedFlashMode);
      await controller.setFocusMode(FocusMode.auto);
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } on CameraException catch (error) {
      final denied = error.code.contains('AccessDenied') || error.code.contains('Permission');
      _close(denied ? widget.strings.cameraPermissionDenied : widget.strings.cameraUnavailable);
    }
  }

  void _close(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    Navigator.of(context).pop();
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final index = _flashModes.indexOf(_selectedFlashMode);
    _selectedFlashMode = _flashModes[(index + 1) % _flashModes.length];
    try {
      await _cameraController?.setFlashMode(_selectedFlashMode);
    } on CameraException {
      // Front cameras usually have no torch; keep the icon in sync anyway.
    }
    if (mounted) setState(() {});
  }

  Future<void> _onTapFocus(TapUpDetails details, Size size) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final point = Offset(details.localPosition.dx / size.width, details.localPosition.dy / size.height);
    setState(() => _focusPoint = details.localPosition);
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } on CameraException {
      // Not every camera supports a focus point.
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) return;
    setState(() => _isTakingPicture = true);
    try {
      final picture = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(picture.path);
    } on CameraException {
      if (!mounted) return;
      setState(() => _isTakingPicture = false);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(widget.strings.cameraUnavailable), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_isCameraInitialized && controller != null)
                    Positioned.fill(child: _buildCameraPreview(controller))
                  else
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _RoundButton(
                      icon: BaseIcons.close,
                      color: theme.previewSurfaceColor,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RoundButton(
                      icon: _selectedFlashMode == FlashMode.off ? BaseIcons.boltOff : BaseIcons.bolt,
                      color: theme.previewSurfaceColor,
                      onTap: _isCameraInitialized ? _toggleFlash : null,
                    ),
                  ),
                  if (_isCameraInitialized && _maxZoomLevel > _minZoomLevel)
                    Positioned(left: 16, right: 16, bottom: 8, child: _buildZoomSlider()),
                ],
              ),
            ),
            _buildControls(theme),
          ],
        ),
      ),
    );
  }

  /// The full, uncropped sensor frame (letterboxed), so the photo matches the
  /// live preview. `previewSize` is in the sensor's landscape orientation,
  /// hence the inverted ratio on a portrait screen.
  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    final preview = previewSize == null
        ? CameraPreview(controller)
        : AspectRatio(aspectRatio: previewSize.height / previewSize.width, child: CameraPreview(controller));
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) => _onTapFocus(details, constraints.biggest),
            child: Stack(
              children: [
                preview,
                if (_focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 20,
                    top: _focusPoint!.dy - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildZoomSlider() {
    return ValueListenableBuilder<double>(
      valueListenable: _zoomLevel,
      builder: (context, value, child) {
        return Row(
          children: [
            const Icon(Icons.remove, color: Colors.white),
            Expanded(
              child: Slider(
                min: _minZoomLevel,
                max: _maxZoomLevel,
                value: value.clamp(_minZoomLevel, _maxZoomLevel),
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
                onChanged: (value) {
                  _zoomLevel.value = value;
                  _cameraController?.setZoomLevel(value);
                },
              ),
            ),
            const Icon(Icons.add, color: Colors.white),
          ],
        );
      },
    );
  }

  Widget _buildControls(NusaChatTheme theme) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                label: 'Ambil foto',
                child: GestureDetector(
                  onTap: _isTakingPicture ? null : _takePicture,
                  child: Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isTakingPicture ? Colors.white54 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _RoundButton(
                icon: BaseIcons.cameraRotate,
                color: theme.previewSurfaceColor,
                size: 48,
                onTap: _cameras.length < 2 || !_isCameraInitialized ? null : _toggleCamera,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const _RoundButton({required this.icon, required this.color, this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: WidgetSvgIcon(icon, size: size / 2, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

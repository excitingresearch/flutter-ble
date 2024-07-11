import 'package:flutter/material.dart';

class ToggleImageButton extends StatefulWidget {
  final String initialImage;
  final String toggledImage;
  final bool initialState;
  final bool? disabled;
  final ValueChanged<bool> onToggle;

  const ToggleImageButton({
    Key? key,
    required this.initialImage,
    required this.toggledImage,
    required this.initialState,
    required this.onToggle,
    this.disabled,
  }) : super(key: key);

  @override
  _ToggleImageButtonState createState() => _ToggleImageButtonState();
}

class _ToggleImageButtonState extends State<ToggleImageButton> {
  late String _imagePath;
  late bool _isToggled;
  late bool _enable;

  @override
  void initState() {
    super.initState();
    _isToggled = widget.initialState;
    _enable = widget.disabled == null ? true : !widget.disabled!;
    _imagePath = _isToggled ? widget.toggledImage : widget.initialImage;
  }

  void _toggleImage() {
    if (_enable) {
      setState(() {
        _isToggled = !_isToggled;
        _imagePath = _isToggled ? widget.toggledImage : widget.initialImage;
      });
      widget.onToggle(_isToggled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: _toggleImage,
        child: Container(
          height: MediaQuery.of(context).size.width /
              4, // Ensuring the buttons are square
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage(_imagePath),
                fit: BoxFit.cover,
                opacity: _enable ? 1 : 0.8),
            border: null, // Optional: add a border to distinguish the buttons
          ),
        ),
      ),
    );
  }
}

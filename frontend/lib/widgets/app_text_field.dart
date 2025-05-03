import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/theme.dart';

class AppTextField extends StatefulWidget {
  final String? label;
  final String? labelText; // 添加labelText参数，与label同义
  final String? hint;
  final String? hintText; // 添加hintText参数，与hint同义
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final Color? fillColor;
  final bool showCounter;
  final String? Function(String?)? validator;
  final AutovalidateMode autovalidateMode;

  const AppTextField({
    Key? key,
    this.label,
    this.labelText, // 添加labelText参数
    this.hint,
    this.hintText, // 添加hintText参数
    this.errorText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding,
    this.style,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.fillColor,
    this.showCounter = false,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(key: key);

  @override
  _AppTextFieldState createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = false;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscureText,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      style: widget.style ?? theme.textTheme.bodyLarge,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      decoration: InputDecoration(
        labelText: widget.labelText ?? widget.label,
        hintText: widget.hintText ?? widget.hint,
        errorText: widget.errorText,
        filled: true,
        fillColor: widget.fillColor ?? (theme.brightness == Brightness.light ? Colors.white : Color(0xFF2C2C2C)),
        contentPadding: widget.contentPadding ?? EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: widget.labelStyle ?? TextStyle(
          color: _isFocused ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
        ),
        hintStyle: widget.hintStyle ?? TextStyle(
          color: AppTheme.textLightColor,
        ),
        errorStyle: widget.errorStyle ?? TextStyle(
          color: AppTheme.errorColor,
          fontSize: 12,
        ),
        prefixIcon: widget.prefixIcon != null ? Icon(
          widget.prefixIcon,
          color: _isFocused ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
        ) : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : widget.suffixIcon != null
                ? IconButton(
                    icon: Icon(
                      widget.suffixIcon,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onPressed: widget.onSuffixIconPressed,
                  )
                : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.textLightColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.textLightColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
        ),
        counterText: widget.showCounter ? null : '',
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/design_system/design_system.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final String? errorText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool enableVisibilityToggle;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.enableVisibilityToggle = false,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.moto.accent,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: context.moto.accent,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: widget.enableVisibilityToggle
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: context.moto.accent,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            hintStyle: GoogleFonts.robotoFlex(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: context.moto.accent,
              letterSpacing: 0.2,
            ),
            filled: !widget.enabled,
            fillColor: context.moto.bgSunken,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: context.moto.accent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: context.moto.accent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  BorderSide(color: context.moto.accent, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: context.moto.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: context.moto.danger, width: 2),
            ),
            errorText: widget.errorText,
          ),
        ),
      ],
    );
  }
}

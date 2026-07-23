import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/blocs/profile_bloc.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _userId;
  String? _token;
  bool _hasUnsavedChanges = false;
  String? _fullNameError;
  String? _emailError;
  String? _phoneError;
  File? _pendingPhoto;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authStorage = Modular.get<AuthStorage>();
    final userId = await authStorage.getUserId();
    final token = await authStorage.getToken();
    if (userId != null && mounted) {
      _userId = userId;
      _token = token;
      context.read<ProfileBloc>().add(LoadProfile(userId));
    }
  }

  Future<void> _handleDeleteAccount() async {
    await Modular.to.pushNamed('/delete-account');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final state = context.read<ProfileBloc>().state;
    if (state is ProfileLoaded) {
      final hasChanges = _fullNameController.text != state.profile.fullName ||
          _emailController.text != state.profile.email ||
          _phoneController.text != (state.profile.phone ?? '');
      if (hasChanges != _hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = hasChanges;
        });
      }
    }
  }

  void _populateControllers(ProfileEntity profile) {
    _fullNameController.text = profile.fullName;
    _emailController.text = profile.email;
    _phoneController.text = profile.phone ?? '';
    _hasUnsavedChanges = false;
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _fullNameError = null;
      _emailError = null;
      _phoneError = null;

      if (_fullNameController.text.trim().isEmpty) {
        _fullNameError = 'Nome é obrigatório';
        valid = false;
      }
      if (_emailController.text.trim().isEmpty) {
        _emailError = 'Email é obrigatório';
        valid = false;
      } else if (!_isValidEmail(_emailController.text.trim())) {
        _emailError = 'Email inválido';
        valid = false;
      }
      if (_phoneController.text.trim().isNotEmpty) {
        final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.length < 10 || digits.length > 11) {
          _phoneError = 'Telefone inválido. Use DDD + número.';
          valid = false;
        }
      }
    });
    return valid;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _formatPhone(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length <= 10) {
      // (XX) XXXX-XXXX
      final parts = <String>[];
      if (digits.length > 2) {
        parts.add('(${digits.substring(0, 2)})');
        if (digits.length > 6) {
          parts.add(' ${digits.substring(2, 6)}-${digits.substring(6)}');
        } else {
          parts.add(' ${digits.substring(2)}');
        }
      } else {
        parts.add(digits);
      }
      return parts.join();
    } else {
      // (XX) XXXXX-XXXX
      final parts = <String>[];
      if (digits.length > 2) {
        parts.add('(${digits.substring(0, 2)})');
        if (digits.length > 7) {
          parts.add(' ${digits.substring(2, 7)}-${digits.substring(7)}');
        } else {
          parts.add(' ${digits.substring(2)}');
        }
      } else {
        parts.add(digits);
      }
      return parts.join();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges && _pendingPhoto == null) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Você tem alterações não salvas. Deseja descartá-las?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _saveProfile() {
    if (!_validate()) return;

    final phoneText = _phoneController.text.trim();
    final phone = phoneText.isNotEmpty
        ? phoneText.replaceAll(RegExp(r'[^\d]'), '')
        : null;

    context.read<ProfileBloc>().add(
          SaveProfile(
            UpdateProfileRequest(
              fullName: _fullNameController.text.trim(),
              email: _emailController.text.trim(),
              phone: phone,
            ),
          ),
        );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xFile != null && mounted) {
        final file = File(xFile.path);
        // Validate size (max 5MB)
        final bytes = await file.length();
        if (bytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A imagem é muito grande. Máximo 5MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        setState(() {
          _pendingPhoto = file;
        });
        // Auto-upload after selection
        final uid = _userId;
        if (uid != null) {
          context.read<ProfileBloc>().add(UploadPhoto(uid, file));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_hasPhoto()) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remover foto',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.read<ProfileBloc>().add(const RemovePhoto());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasPhoto() {
    final state = context.read<ProfileBloc>().state;
    return switch (state) {
      ProfileLoaded(:final profile) => profile.photoUrl != null,
      ProfileSaveSuccess(:final profile) => profile.photoUrl != null,
      ProfilePhotoUpdated(:final profile) => profile.photoUrl != null,
      ProfilePhotoRemoved() => false,
      ProfilePhotoError(:final profile) => profile.photoUrl != null,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_hasUnsavedChanges && _pendingPhoto == null,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            title: Text(
              'Meu Perfil',
              style: GoogleFonts.robotoFlex(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            backgroundColor: AppColors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () async {
                if (_hasUnsavedChanges || _pendingPhoto != null) {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && mounted) {
                    Navigator.of(context).pop();
                  }
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          body: BlocConsumer<ProfileBloc, ProfileState>(
              listener: (context, state) {
                switch (state) {
                  case ProfileSaveSuccess():
                    setState(() {
                      _hasUnsavedChanges = false;
                      _pendingPhoto = null;
                    });
                    _populateControllers(state.profile);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Perfil atualizado com sucesso'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  case ProfileSaveError(:final message):
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  case ProfilePhotoUpdated():
                    setState(() {
                      _pendingPhoto = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Foto atualizada'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  case ProfilePhotoRemoved():
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Foto removida'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  case ProfilePhotoError(:final message):
                    setState(() {
                      _pendingPhoto = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  case ProfileError(:final message):
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: 'Tentar novamente',
                          textColor: Colors.white,
                          onPressed: _loadProfile,
                        ),
                      ),
                    );
                  default:
                    break;
                }
              },
              builder: (context, state) {
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                    child: Column(
                      children: [
                        _buildAvatar(state),
                        const SizedBox(height: 32),
                        _buildForm(state),
                        const SizedBox(height: 24),
                        _buildSaveButton(state),
                        const SizedBox(height: 32),
                        _buildDeleteAccountSection(),
                      ],
                    ),
                  ),
                );
              },
          ),
        ),
    );
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.getBaseUrl()}$url';
  }

  Map<String, String>? get _authHeaders {
    final token = _token;
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Widget _buildAvatar(ProfileState state) {
    final isLoading = state is ProfileLoading;
    final isUploading = state is ProfilePhotoUploading;
    final uploadProgress = isUploading ? (state).progress : 0.0;

    String? photoUrl;
    switch (state) {
      case ProfileLoaded(:final profile):
        photoUrl = profile.photoUrl;
      case ProfileSaveSuccess(:final profile):
        photoUrl = profile.photoUrl;
      case ProfilePhotoUploading(:final profile):
        photoUrl = profile.photoUrl;
      case ProfilePhotoUpdated(:final profile):
        photoUrl = profile.photoUrl;
      case ProfilePhotoRemoved():
        photoUrl = null;
      case ProfilePhotoError(:final profile):
        photoUrl = profile.photoUrl;
      default:
        photoUrl = null;
    }

    return GestureDetector(
      onTap: isLoading ? null : _showPhotoOptions,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withAlpha(30),
            backgroundImage:
                photoUrl != null
                    ? NetworkImage(
                        _resolveImageUrl(photoUrl),
                        headers: _authHeaders,
                      )
                    : null,
            child: photoUrl == null
                ? Text(
                    _getInitials(),
                    style: GoogleFonts.robotoFlex(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          if (isUploading)
            Positioned.fill(
              child: CircularProgressIndicator(
                value: uploadProgress,
                strokeWidth: 3,
                backgroundColor: AppColors.primary.withAlpha(30),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: AppColors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    final state = context.read<ProfileBloc>().state;
    String name;
    switch (state) {
      case ProfileLoaded(:final profile):
        name = profile.fullName;
      case ProfileSaveSuccess(:final profile):
        name = profile.fullName;
      case ProfilePhotoUpdated(:final profile):
        name = profile.fullName;
      case ProfilePhotoRemoved(:final profile):
        name = profile.fullName;
      default:
        return '';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildForm(ProfileState state) {
    if (state is ProfileLoading) {
      return _buildSkeleton();
    }

    if (state is ProfileError) {
      return Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            state.message,
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Tentar novamente',
            onPressed: _loadProfile,
          ),
        ],
      );
    }

    // Populate controllers when profile is first loaded
    if (state is ProfileLoaded && _fullNameController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateControllers(state.profile);
      });
    }
    if (state is ProfileSaveSuccess && _fullNameController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateControllers(state.profile);
      });
    }

    return Column(
      spacing: 16,
      children: [
        AppTextField(
          label: 'Nome completo',
          hint: 'Seu nome completo',
          controller: _fullNameController,
          errorText: _fullNameError,
          onChanged: (_) {
            _onFieldChanged();
            setState(() {
              _fullNameError = null;
            });
          },
        ),
        AppTextField(
          label: 'Email',
          hint: 'seu@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) {
            _onFieldChanged();
            setState(() {
              _emailError = null;
            });
          },
        ),
        _buildPhoneField(),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Telefone',
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: (value) {
            final formatted = _formatPhone(value);
            if (formatted != value) {
              _phoneController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
            _onFieldChanged();
            setState(() {
              _phoneError = null;
            });
          },
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: '(11) 91234-5678',
            hintStyle: GoogleFonts.robotoFlex(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorText: _phoneError,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Column(
      spacing: 16,
      children: [
        _buildSkeletonItem(),
        _buildSkeletonItem(),
        _buildSkeletonItem(),
      ],
    );
  }

  Widget _buildSkeletonItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(50),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(30),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ProfileState state) {
    final isLoading = state is ProfileLoading;
    final isSaving = state is ProfileSaving;
    final isUploading = state is ProfilePhotoUploading;
    final isDisabled = isLoading || isSaving || isUploading;

    return Column(
      children: [
        AppButton(
          label: 'Salvar',
          loading: isSaving,
          onPressed: isDisabled ? null : _saveProfile,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isDisabled
              ? null
              : () async {
                  if (_hasUnsavedChanges || _pendingPhoto != null) {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && mounted) {
                      Navigator.of(context).pop();
                    }
                  } else {
                    Navigator.of(context).pop();
                  }
                },
          child: Text(
            'Cancelar',
            style: GoogleFonts.robotoFlex(
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteAccountSection() {
    return Column(
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 20),
        const Text(
          'Zona de Perigo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ao excluir sua conta, todos os seus dados serão perdidos '
          'e você não poderá mais acessar o aplicativo.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6B6B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _handleDeleteAccount,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              'Excluir minha conta',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

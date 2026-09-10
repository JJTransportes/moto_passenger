import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moto_passenger/core/auth/auth_storage.dart';
import 'package:moto_passenger/core/auth/sign_out_service.dart';
import 'package:moto_passenger/core/config/app_config.dart';
import 'package:moto_passenger/core/network/signalr_service.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/core/utils/masks.dart';
import 'package:moto_passenger/core/utils/validators.dart' as validators;
import 'package:moto_passenger/modules/passenger_home/domain/repositories/i_passenger_home_repository.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_passenger/modules/profile_configuration/domain/entities/update_profile_request.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/blocs/profile_bloc.dart';
import 'package:moto_passenger/modules/profile_configuration/presentation/widgets/confirm_password_dialog.dart';
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
  final _confirmEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _userId;
  String? _token;
  bool _hasUnsavedChanges = false;
  String? _fullNameError;
  String? _emailError;
  String? _phoneError;
  File? _pendingPhoto;

  bool _isEditing = false;
  bool _checkingActiveTravel = true;
  bool _hasActiveTravel = true;
  String? _originalFullName;
  String? _originalEmail;
  String? _originalPhone;
  bool _pendingEmailChange = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkActiveTravel();
    _confirmEmailController.addListener(_onFieldChanged);
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

  Future<void> _checkActiveTravel() async {
    final repository = Modular.get<IPassengerHomeRepository>();
    final result = await repository.getActiveTravel();
    if (!mounted) return;
    setState(() {
      _checkingActiveTravel = false;
      _hasActiveTravel = result.fold(
        (travels) => travels.isNotEmpty,
        (_) => true,
      );
    });
  }

  bool get _isBlockedByActiveTravel => _checkingActiveTravel || _hasActiveTravel;

  Future<void> _handleDeleteAccount() async {
    await Modular.to.pushNamed('/delete-account');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
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
      } else {
        setState(() {});
      }
    }
  }

  void _populateControllers(ProfileEntity profile) {
    _fullNameController.text = profile.fullName;
    _emailController.text = profile.email;
    _phoneController.text = profile.phone ?? '';
    _originalFullName = profile.fullName;
    _originalEmail = profile.email;
    _originalPhone = profile.phone ?? '';
    _hasUnsavedChanges = false;
  }

  String? get _confirmEmailMismatch {
    final email = _emailController.text.trim().toLowerCase();
    final confirmEmail = _confirmEmailController.text.trim().toLowerCase();
    if (email.isEmpty || confirmEmail.isEmpty) return null;
    if (email == confirmEmail) return null;
    return 'Os e-mails não coincidem';
  }

  bool get _isEmailConfirmed =>
      _emailController.text.trim().toLowerCase() ==
      _confirmEmailController.text.trim().toLowerCase();

  bool get _isFormFilled =>
      _fullNameController.text.trim().isNotEmpty &&
      validators.validateEmail(_emailController.text) == null &&
      _isEmailConfirmed &&
      (_phoneController.text.trim().isEmpty ||
          _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 10);

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
      _emailError = validators.validateEmail(_emailController.text);
      if (_emailError != null) valid = false;

      if (_confirmEmailMismatch != null) {
        valid = false;
      } else if (_confirmEmailController.text.trim().isEmpty) {
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

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _confirmEmailController.clear();
    });
  }

  Future<void> _onActionButtonTapped() async {
    if (!_isEditing) {
      _enterEditMode();
      return;
    }
    await _onSaveTapped();
  }

  Future<void> _onSaveTapped() async {
    if (!_validate()) return;

    final newEmail = _emailController.text.trim();
    final emailChanged = newEmail != (_originalEmail ?? '');

    final password = await showConfirmPasswordDialog(
      context,
      showLogoutWarning: emailChanged,
    );
    if (password == null || !mounted) return;

    _pendingEmailChange = emailChanged;
    _submitSave(password, emailChanged ? newEmail : null);
  }

  void _submitSave(String password, String? newEmail) {
    final newFullName = _fullNameController.text.trim();
    final phoneText = _phoneController.text.trim();
    final newPhone = phoneText.isNotEmpty
        ? phoneText.replaceAll(RegExp(r'[^\d]'), '')
        : null;

    final uid = _userId;
    if (uid == null) return;

    context.read<ProfileBloc>().add(
          SaveProfile(
            uid,
            UpdateProfileRequest(
              fullName: newFullName != (_originalFullName ?? '') ? newFullName : null,
              email: newEmail,
              phone: newPhone != _originalPhone ? newPhone : null,
              password: password,
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
                  final uid = _userId;
                  if (uid != null) {
                    context.read<ProfileBloc>().add(RemovePhoto(uid));
                  }
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
                    if (_pendingEmailChange) {
                      Modular.get<SignalRService>().disconnectAll().whenComplete(
                            () => Modular.get<SignOutService>().signOut(),
                          );
                      return;
                    }
                    setState(() {
                      _hasUnsavedChanges = false;
                      _pendingPhoto = null;
                      _isEditing = false;
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
                        _buildActionButton(state),
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
      onTap: (isLoading || _isBlockedByActiveTravel) ? null : _showPhotoOptions,
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
              decoration: BoxDecoration(
                color: _isBlockedByActiveTravel ? Colors.grey : AppColors.primary,
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

    if (state is ProfileLoaded && _fullNameController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _populateControllers(state.profile));
      });
    }
    if (state is ProfileSaveSuccess && _fullNameController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _populateControllers(state.profile));
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
          enabled: _isEditing,
          onChanged: (_) {
            _onFieldChanged();
            setState(() {
              _fullNameError = null;
            });
          },
        ),
        _buildDisplayOrEditableEmail(),
        if (_isEditing)
          AppTextField(
            label: 'Confirmar e-mail',
            hint: 'Repita seu e-mail',
            controller: _confirmEmailController,
            keyboardType: TextInputType.emailAddress,
            errorText: _confirmEmailMismatch,
          ),
        _buildPhoneField(),
      ],
    );
  }

  Widget _buildDisplayOrEditableEmail() {
    if (!_isEditing) {
      return AppTextField(
        label: 'Email',
        hint: 'seu@email.com',
        controller: TextEditingController(text: maskEmail(_emailController.text)),
        enabled: false,
      );
    }
    return AppTextField(
      label: 'Email',
      hint: 'seu@email.com',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      errorText: _emailError,
      enabled: true,
      onChanged: (_) {
        _onFieldChanged();
        setState(() {
          _emailError = null;
        });
      },
    );
  }

  Widget _buildPhoneField() {
    if (!_isEditing) {
      return _buildPhoneFieldRaw(
        controller: TextEditingController(
          text: _phoneController.text.isNotEmpty ? maskPhone(_phoneController.text) : '',
        ),
        enabled: false,
        onChanged: null,
      );
    }
    return _buildPhoneFieldRaw(
      controller: _phoneController,
      enabled: true,
      onChanged: (value) {
        _onFieldChanged();
        setState(() {
          _phoneError = null;
        });
      },
    );
  }

  Widget _buildPhoneFieldRaw({
    required TextEditingController controller,
    required bool enabled,
    required ValueChanged<String>? onChanged,
  }) {
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
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          onChanged: onChanged,
          inputFormatters: [PhoneInputFormatter()],
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: '(11) 91234-5678 (opcional)',
            hintStyle: GoogleFonts.robotoFlex(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
            filled: !enabled,
            fillColor: Colors.grey.shade100,
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

  Widget _buildActionButton(ProfileState state) {
    final isLoading = state is ProfileLoading;
    final isSaving = state is ProfileSaving;
    final isUploading = state is ProfilePhotoUploading;
    final isBusy = isLoading || isSaving || isUploading;

    final canAct = !isBusy && !_isBlockedByActiveTravel;

    void cancelEdit() {
      setState(() => _isEditing = false);
      if (_originalFullName != null) {
        _fullNameController.text = _originalFullName!;
        _emailController.text = _originalEmail!;
        _phoneController.text = _originalPhone ?? '';
      }
      _hasUnsavedChanges = false;
    }

    if (!_isEditing) {
      return AppButton(
        label: 'Editar',
        loading: isSaving,
        onPressed: canAct ? _onActionButtonTapped : null,
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isBusy ? null : cancelEdit,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.robotoFlex(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: 'Salvar',
            loading: isSaving,
            onPressed: (canAct && _isFormFilled) ? _onActionButtonTapped : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteAccountSection() {
    final isBlocked = _isBlockedByActiveTravel;

    return Column(
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 20),
        Text(
          'Zona de Perigo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isBlocked ? Colors.grey : Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isBlocked
              ? 'Você não pode excluir sua conta enquanto tiver uma viagem em andamento.'
              : 'Ao excluir sua conta, todos os seus dados serão perdidos '
                  'e você não poderá mais acessar o aplicativo.',
          style: TextStyle(
            fontSize: 12,
            color: isBlocked ? Colors.grey : const Color(0xFF6B6B6B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isBlocked ? null : _handleDeleteAccount,
            icon: Icon(
              Icons.delete_forever,
              color: isBlocked ? Colors.grey : Colors.red,
            ),
            label: Text(
              'Excluir minha conta',
              style: TextStyle(color: isBlocked ? Colors.grey : Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isBlocked ? Colors.grey : Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

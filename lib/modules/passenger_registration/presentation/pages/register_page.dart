import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_passenger/core/theme/app_theme.dart';
import 'package:moto_passenger/core/utils/masks.dart';
import 'package:moto_passenger/core/utils/validators.dart' as validators;
import 'package:moto_passenger/modules/passenger_registration/domain/entities/department_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/domain/entities/public_partition_entity.dart';
import 'package:moto_passenger/modules/passenger_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_passenger/widgets/app_button.dart';
import 'package:moto_passenger/widgets/app_text_field.dart';
import 'package:moto_passenger/widgets/gradient_text.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _fullNameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();
  final _registrationController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthdateController = TextEditingController();

  String? _selectedPartitionId;
  String? _selectedDepartmentName;
  List<PublicPartition> _partitions = [];
  Department? _selectedDepartment;

  DateTime? _birthdate;

  String? _fullNameError;
  String? _cpfError;
  String? _rgError;
  String? _registrationError;
  String? _emailError;
  String? _passwordError;
  String? _birthdateError;
  String? _partitionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RegisterBloc>().add(const LoadPartitions());
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _registrationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  void _onPartitionChanged(String? partitionId) {
    setState(() {
      _selectedPartitionId = partitionId;
      _selectedDepartment = null;
      _selectedDepartmentName = null;
      _partitionError = null;
    });
  }

  void _onDepartmentChanged(Department? department) {
    setState(() {
      _selectedDepartment = department;
      _selectedDepartmentName = department?.name;
    });
  }

  List<Department> get _availableDepartments {
    if (_selectedPartitionId == null) return [];
    final partition = _partitions.firstWhere(
      (p) => p.partitionId == _selectedPartitionId,
      orElse: () => _partitions.first,
    );
    return partition.departments;
  }

  bool get _hasDepartments => _availableDepartments.isNotEmpty;

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked != null) {
      setState(() {
        _birthdate = picked;
        _birthdateController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        _birthdateError = null;
      });
    }
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _fullNameError = validators.validateFullName(_fullNameController.text) ??
          validators.validateSafeText(_fullNameController.text, 'Nome completo');
      _cpfError = validators.validateCpf(_cpfController.text);
      _rgError = validators.validateRg(_rgController.text);
      _registrationError = validators.validateRequired(
              _registrationController.text, 'Matrícula') ??
          validators.validateAlphanumericFormat(
              _registrationController.text, 'Matrícula', 30);
      _emailError = validators.validateEmail(_emailController.text);
      _passwordError = validators.validatePassword(_passwordController.text);
      _birthdateError =
          _birthdate == null ? 'Data de nascimento obrigatória' : null;
      _partitionError = _selectedPartitionId == null ? 'Selecione um órgão' : null;

      valid = _fullNameError == null &&
          _cpfError == null &&
          _rgError == null &&
          _registrationError == null &&
          _emailError == null &&
          _passwordError == null &&
          _birthdateError == null &&
          _partitionError == null;
    });
    return valid;
  }

  void _submit() {
    if (!_validate()) return;
    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        fullName: _fullNameController.text.trim(),
        cpf: _cpfController.text.trim(),
        rg: _rgController.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
        registration: _registrationController.text.trim(),
        birthdate: _birthdate!,
        email: _emailController.text.trim(),
        initialPassword: _passwordController.text,
        department: _selectedDepartmentName,
        publicPartitionId: _selectedPartitionId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          Modular.to.pushNamed('/pending-approval');
        }
      },
      builder: (context, state) {
        final isSubmitting = state is RegisterSubmitting;
        final errorMessage = state is RegisterFailure ? state.message : null;

        if (state is PartitionsLoaded) {
          _partitions = state.partitions;
        }

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GradientText(
                    'Criar Conta',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildForm(state),
                  const SizedBox(height: 16),
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppButton(
                    label: 'Criar conta',
                    loading: isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isSubmitting ? null : () => Modular.to.pop(),
                    child: Text(
                      'Já tem conta? Entrar',
                      style: GoogleFonts.robotoFlex(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(RegisterState state) {
    if (state is PartitionsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state is PartitionsError) {
      return Column(
        children: [
          Text(
            state.message,
            style: const TextStyle(color: Colors.red, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Tentar novamente',
            onPressed: () {
              context.read<RegisterBloc>().add(const LoadPartitions());
            },
          ),
        ],
      );
    }

    return Column(
      spacing: 12,
      children: [
        _buildPartitionDropdown(),
        if (_hasDepartments) _buildDepartmentDropdown(),
        AppTextField(
          label: 'Nome completo *',
          hint: 'Informe seu nome completo',
          controller: _fullNameController,
          errorText: _fullNameError,
          maxLength: 100,
        ),
        AppTextField(
          label: 'CPF *',
          hint: '000.000.000-00',
          controller: _cpfController,
          keyboardType: TextInputType.number,
          errorText: _cpfError,
          inputFormatters: [CpfInputFormatter()],
          maxLength: 14,
        ),
        AppTextField(
          label: 'RG *',
          hint: 'Somente letras e números (7 a 12 caracteres)',
          controller: _rgController,
          keyboardType: TextInputType.text,
          errorText: _rgError,
          inputFormatters: [AlphanumericInputFormatter(maxLength: 12)],
          maxLength: 12,
        ),
        AppTextField(
          label: 'Matrícula *',
          hint: 'N° de matrícula (letras e números)',
          controller: _registrationController,
          keyboardType: TextInputType.text,
          errorText: _registrationError,
          inputFormatters: [AlphanumericInputFormatter(maxLength: 30)],
          maxLength: 30,
        ),
        _buildBirthdateField(),
        AppTextField(
          label: 'E-mail *',
          hint: 'Informe seu e-mail',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          maxLength: 100,
        ),
        AppTextField(
          label: 'Senha *',
          hint: 'Mínimo 8 caracteres',
          controller: _passwordController,
          obscureText: true,
          enableVisibilityToggle: true,
          errorText: _passwordError,
          maxLength: 72,
        ),
      ],
    );
  }

  Widget _buildPartitionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Órgão',
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _partitionError != null ? Colors.red : AppColors.primary,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPartitionId,
              hint: Text(
                'Selecione um órgão',
                style: GoogleFonts.robotoFlex(
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primary,
                ),
              ),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: BorderRadius.circular(4),
              items: _partitions.map((p) {
                return DropdownMenuItem(
                  value: p.partitionId,
                  child: Text(
                    '${p.name} (${p.acronym})',
                    style: GoogleFonts.robotoFlex(
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _onPartitionChanged,
            ),
          ),
        ),
        if (_partitionError != null) ...[
          const SizedBox(height: 4),
          Text(
            _partitionError!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Secretaria',
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primary),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Department>(
              value: _selectedDepartment,
              hint: Text(
                'Selecione uma secretaria',
                style: GoogleFonts.robotoFlex(
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primary,
                ),
              ),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: BorderRadius.circular(4),
              items: _availableDepartments.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(
                    d.name,
                    style: GoogleFonts.robotoFlex(
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _onDepartmentChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data de nascimento',
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
          controller: _birthdateController,
          readOnly: true,
          onTap: _pickBirthdate,
          style: GoogleFonts.robotoFlex(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: AppColors.primary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'DD/MM/AAAA',
            hintStyle: GoogleFonts.robotoFlex(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
            suffixIcon: const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.primary,
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
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorText: _birthdateError,
          ),
        ),
      ],
    );
  }
}

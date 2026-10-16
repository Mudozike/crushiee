// DEPRECATED LEGACY FILE: This screen is kept for backwards compatibility only.
// The active, production Profile Setup screen used by the application is
// located at lib/screens/profile/profile_setup_screen.dart.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/crushie_avatar.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String username;
  final String email;
  final VoidCallback onSetupComplete;

  const ProfileSetupScreen({
    Key? key,
    required this.onSetupComplete,
    required this.username,
    required this.email,
  }) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  int _selectedMascotIndex = 0;
  File? _customImageFile;

  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _phoneNumberController;

  DateTime _selectedDateOfBirth = DateTime(2000, 1, 1);
  String _selectedGender = AppConstants.genderOptions.first;
  String _selectedCountry = AppConstants.countries.first;
  String _selectedContactMethod = 'WhatsApp';
  String _selectedLookingFor = 'Relationship';

  bool _isSubmittedSuccess = false;

  final List<String> _lookingForChips = [
    'Relationship',
    'Friendship',
    'Something casual',
    'Not sure yet',
  ];

  final List<String> _connectMethods = [
    'WhatsApp',
    'Crushie Chat',
    'Telegram',
    'Phone',
  ];

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController();
    _cityController = TextEditingController(text: 'Nairobi');
    _phoneNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _customImageFile = File(pickedFile.path);
      });
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  bool get _isPhoneValid =>
      _phoneNumberController.text.trim().isNotEmpty &&
      RegExp(r'^\+?[0-9]{7,15}$').hasMatch(
          _phoneNumberController.text.trim().replaceAll(RegExp(r'[\s\-]'), ''));

  bool get _isAgeValid => _calculateAge(_selectedDateOfBirth) >= 18;
  bool get _isBioValid => _bioController.text.trim().isNotEmpty;
  bool get _isCityValid => _cityController.text.trim().isNotEmpty;

  List<String> _getMissingFields() {
    final List<String> missing = [];
    if (!_isCityValid) missing.add('Add your location (City)');
    if (!_isBioValid) missing.add('Add a short bio about yourself');
    if (!_isPhoneValid) missing.add('Add your phone number / contact details');
    if (!_isAgeValid) missing.add('Be 18 years or older (Date of Birth)');
    return missing;
  }

  Future<void> _handleCompleteProfile(AuthProvider authProv) async {
    final missing = _getMissingFields();
    if (missing.isNotEmpty) {
      // Focus/Scroll to top or missing field
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.primary, size: 26),
              SizedBox(width: 8),
              Text('Please Complete Profile',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please complete the following required fields:'),
              const SizedBox(height: 12),
              ...missing.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final avatarUrl = _customImageFile != null
          ? _customImageFile!.path
          : 'crushie_avatar_$_selectedMascotIndex';

      final uid = authProv.currentUser?.id ?? '';
      final newUser = UserModel(
        id: uid,
        username: widget.username,
        email: widget.email,
        country: _selectedCountry,
        city: _cityController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        gender: _selectedGender,
        bio:
            '${_bioController.text.trim()}\n\nLooking for: $_selectedLookingFor',
        profilePicUrl: avatarUrl,
        preferredContactMethod: _selectedContactMethod,
        contactDetails: _phoneNumberController.text.trim(),
      );

      await authProv.updateUserProfile(newUser);

      setState(() {
        _isSubmittedSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    if (_isSubmittedSuccess) {
      return _buildSuccessState(isDark);
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Setup Profile',
          style: TextStyle(
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Header
                    Text(
                      'Choose Your Crushie Avatar',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose an avatar that represents your vibe, or upload your own photo.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar Preview
                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _customImageFile != null
                              ? Image.file(
                                  _customImageFile!,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                )
                              : CrushieAvatar(
                                  index: _selectedMascotIndex,
                                  radius: 55,
                                  isSelected: true,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Choose an avatar:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: CrushieAvatar.avatarPresets.length,
                        itemBuilder: (ctx, i) {
                          final isSelected = _customImageFile == null &&
                              _selectedMascotIndex == i;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _customImageFile = null;
                                _selectedMascotIndex = i;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: CrushieAvatar(
                                index: i,
                                radius: 30,
                                isSelected: isSelected,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _pickCustomImage,
                        icon: const Icon(Icons.camera_alt_outlined,
                            color: AppColors.primary, size: 18),
                        label: const Text(
                          '📷 Upload Photo',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Divider(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    const SizedBox(height: 20),

                    Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Date of Birth Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date of Birth',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat('dd MMM yyyy').format(_selectedDateOfBirth)} • Age ${_calculateAge(_selectedDateOfBirth)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _isAgeValid
                                        ? AppColors.primary
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isAgeValid
                                      ? 'Must be 18+'
                                      : 'You must be 18+ to use Crushie',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        _isAgeValid ? Colors.grey : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000, 1, 1),
                                firstDate: DateTime(1940),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _selectedDateOfBirth = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Change',
                                style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: const Icon(Icons.person_outline,
                            color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      items: AppConstants.genderOptions
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Bio Section
                    Text(
                      'About You',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tell people a little about yourself...',
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Tell us a bit about yourself'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Looking For Selection
                    Text(
                      'What are you looking for?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _lookingForChips.map((option) {
                        final isSelected = _selectedLookingFor == option;
                        return ChoiceChip(
                          label: Text(option),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: isDark
                              ? AppColors.darkCard
                              : Colors.grey.shade200,
                          onSelected: (val) {
                            if (val)
                              setState(() => _selectedLookingFor = option);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Location Section
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCountry,
                            decoration: InputDecoration(
                              labelText: 'Country',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                            ),
                            items: AppConstants.countries
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedCountry = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'City',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter city'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Preferred Way to Connect
                    Text(
                      'Preferred Way to Connect',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedContactMethod,
                      decoration: InputDecoration(
                        labelText: 'Preferred Contact Method',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      items: _connectMethods
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedContactMethod = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: '+254712345678',
                        prefixIcon: const Icon(Icons.phone_outlined,
                            color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 1.2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Phone number is required';
                        final clean =
                            v.trim().replaceAll(RegExp(r'[\s\-]'), '');
                        if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(clean)) {
                          return 'Enter a valid phone number (e.g. +254712345678)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Complete Profile Button
                    GradientButton(
                      text: 'Complete Profile',
                      height: 56,
                      onPressed: () => _handleCompleteProfile(authProv),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 48
                      ? constraints.maxHeight - 48
                      : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'You\'re All Set!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your Crushie profile is ready.\nStart discovering people who match your vibe.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'Start Connecting',
                        height: 56,
                        onPressed: widget.onSetupComplete,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

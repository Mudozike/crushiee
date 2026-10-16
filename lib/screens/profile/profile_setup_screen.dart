import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/crushie_avatar.dart';
import '../../widgets/gradient_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;
  final VoidCallback? onLogout;

  const ProfileSetupScreen({
    Key? key,
    required this.onSetupComplete,
    this.onLogout,
  }) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _contactDetailsController;

  String _selectedCountry = 'Kenya';
  String _selectedGender = 'Female';
  String _selectedContactMethod = 'WhatsApp';
  DateTime _dateOfBirth = DateTime(2000, 1, 1);

  int _selectedAvatarIndex = 0;
  File? _customImageFile;
  String _profilePicUrl = 'crushie_avatar_0';

  bool _isDetectingLocation = false;
  bool _isSaving = false;

  static const List<String> _kenyaCities = [
    'Nairobi',
    'Mombasa',
    'Kisumu',
    'Nakuru',
    'Eldoret',
    'Kiambu',
    'Machakos',
    'Thika',
    'Nyeri',
    'Meru',
    'Kilifi',
    'Kajiado',
    'Naivasha',
    'Kitale',
    'Malindi',
    'Kakamega',
    'Kisii',
    'Kericho',
    'Garissa',
    'Embu',
  ];

  @override
  void initState() {
    super.initState();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;

    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _cityController = TextEditingController(
        text: user?.city.isNotEmpty == true ? user!.city : 'Nairobi');

    // Phone / Contact Details: initialize cleanly without dummy fake numbers
    String initialContact = user?.contactDetails ?? '';
    if (initialContact == '+254712345678' ||
        initialContact == '+254700000000') {
      initialContact = '';
    }
    _contactDetailsController = TextEditingController(text: initialContact);

    if (user != null) {
      if (AppConstants.countries.contains(user.country)) {
        _selectedCountry = user.country;
      }
      if (AppConstants.genderOptions.contains(user.gender)) {
        _selectedGender = user.gender;
      }
      if (AppConstants.contactMethods.contains(user.preferredContactMethod)) {
        _selectedContactMethod = user.preferredContactMethod;
      }
      _dateOfBirth = user.dateOfBirth;

      if (user.profilePicUrl.isNotEmpty &&
          !user.profilePicUrl.contains('googleusercontent.com')) {
        _profilePicUrl = user.profilePicUrl;
        _selectedAvatarIndex = _getAvatarIndex(user.profilePicUrl);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _contactDetailsController.dispose();
    super.dispose();
  }

  int get _calculatedAge {
    final now = DateTime.now();
    int age = now.year - _dateOfBirth.year;
    if (now.month < _dateOfBirth.month ||
        (now.month == _dateOfBirth.month && now.day < _dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  int _getAvatarIndex(String url) {
    if (url.startsWith('crushie_avatar_')) {
      final parsed = int.tryParse(url.replaceFirst('crushie_avatar_', ''));
      if (parsed != null &&
          parsed >= 0 &&
          parsed < CrushieAvatar.avatarPresets.length) {
        return parsed;
      }
    }
    return 0;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        final file = File(picked.path);
        final length = await file.length();
        if (length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Selected photo exceeds the 5MB size limit. Please choose a smaller image.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        setState(() {
          _customImageFile = file;
          _profilePicUrl = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image picker: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _autoDetectGPSLocation() async {
    if (_isDetectingLocation) return;
    setState(() => _isDetectingLocation = true);

    try {
      final result = await LocationService.getCurrentLocation();
      if (!mounted) return;

      if (result.success) {
        setState(() {
          _selectedCountry = result.country;
          _cityController.text = result.city;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Location detected: ${result.city}, ${result.country}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ??
                'Could not automatically detect GPS location. You can type your city or county manually.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location lookup failed: $e. You can type your location manually.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  String _normalizePhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+254')) {
      return cleaned;
    } else if (cleaned.startsWith('07') || cleaned.startsWith('01')) {
      return '+254${cleaned.substring(1)}';
    } else if (cleaned.startsWith('7') || cleaned.startsWith('1')) {
      return '+254$cleaned';
    } else if (cleaned.startsWith('254')) {
      return '+$cleaned';
    }
    return cleaned;
  }

  bool _isValidKenyaPhone(String raw) {
    final norm = _normalizePhoneNumber(raw);
    final reg = RegExp(r'^\+254(7\d{8}|1\d{8})$');
    return reg.hasMatch(norm);
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_calculatedAge < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old to use Crushie.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Session expired or user not signed in. Please log in again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final current = authProv.currentUser;
      final uid = fbUser.uid;

      String finalProfilePic = _profilePicUrl;

      // 1. If custom image was picked from camera or gallery, upload to Firebase Storage first
      if (_customImageFile != null) {
        final uploadedUrl = await StorageService().uploadProfilePicture(
          userId: uid,
          file: XFile(_customImageFile!.path),
        );
        finalProfilePic = uploadedUrl;
      } else if (!finalProfilePic.startsWith('http') &&
          !finalProfilePic.startsWith('crushie_avatar_')) {
        finalProfilePic = 'crushie_avatar_$_selectedAvatarIndex';
      }

      // 2. Format / normalize contact details
      String contactDetails = _contactDetailsController.text.trim();
      if (_selectedContactMethod == 'WhatsApp' ||
          _selectedContactMethod == 'Phone Call') {
        contactDetails = _normalizePhoneNumber(contactDetails);
      }

      // 3. Construct updated UserModel
      final updatedUser = UserModel(
        id: uid,
        username: _usernameController.text.trim(),
        email: fbUser.email ?? current?.email ?? '',
        country: _selectedCountry,
        city: _cityController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _selectedGender,
        bio: _bioController.text.trim(),
        profilePicUrl: finalProfilePic,
        preferredContactMethod: _selectedContactMethod,
        contactDetails: contactDetails,
        profileCompleted: true,
        isVerified: current?.isVerified ?? false,
        verifiedExpiry: current?.verifiedExpiry,
        verificationPhoto: current?.verificationPhoto,
        isPremium: current?.isPremium ?? false,
        premiumExpiry: current?.premiumExpiry,
        dailyConnections: current?.dailyConnections ?? 0,
        dailyConnectionsDate: current?.dailyConnectionsDate,
        monthlyConnections: current?.monthlyConnections ?? 0,
        monthlyConnectionsMonth: current?.monthlyConnectionsMonth,
        followersCount: current?.followersCount ?? 0,
        followingCount: current?.followingCount ?? 0,
        communities: current?.communities ?? const [],
        blockedUserIds: current?.blockedUserIds ?? const [],
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: current?.createdAt ?? DateTime.now(),
      );

      // 4. Save to Firestore
      final success = await authProv.updateUserProfile(updatedUser);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup complete! Welcome to Crushie.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onSetupComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProv.errorMessage ??
                'Failed to save profile. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
        actions: [
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: _isSaving ? null : widget.onLogout,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Main Avatar Preview & Action Controls
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _customImageFile != null
                              ? Image.file(
                                  _customImageFile!,
                                  width: 116,
                                  height: 116,
                                  fit: BoxFit.cover,
                                )
                              : _profilePicUrl.startsWith('http')
                                  ? Image.network(
                                      _profilePicUrl,
                                      width: 116,
                                      height: 116,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          CrushieAvatar(
                                        index: _selectedAvatarIndex,
                                        radius: 58,
                                        isSelected: true,
                                      ),
                                    )
                                  : CrushieAvatar(
                                      index: _selectedAvatarIndex,
                                      radius: 58,
                                      isSelected: true,
                                    ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Camera and Gallery Action Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt,
                                size: 16, color: AppColors.primary),
                            label: const Text(
                              'Take Photo',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library,
                                size: 16, color: AppColors.primary),
                            label: const Text(
                              'Choose Gallery',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 2: Built-in Avatar Horizontal Carousel Selector
                Text(
                  'Or Choose a Mascot Avatar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select one of the 8 signature Crushie avatars below:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 92,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: CrushieAvatar.avatarPresets.length,
                    itemBuilder: (context, index) {
                      final isSelected = _customImageFile == null &&
                          _selectedAvatarIndex == index;
                      return GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _customImageFile = null;
                                  _selectedAvatarIndex = index;
                                  _profilePicUrl = 'crushie_avatar_$index';
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CrushieAvatar(
                                index: index,
                                radius: 28,
                                isSelected: isSelected,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CrushieAvatar.avatarPresets[index]['name']
                                    as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: Username
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'e.g. alex_ke',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Enter a username';
                    if (v.trim().length < 3)
                      return 'Username must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Section 4: Country & City/County Selection
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: AppConstants.countries.contains(_selectedCountry)
                            ? _selectedCountry
                            : 'Kenya',
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          prefixIcon: Icon(Icons.public, size: 18),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 14),
                        ),
                        isExpanded: true,
                        items: AppConstants.countries
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (val) {
                                if (val != null)
                                  setState(() => _selectedCountry = val);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Autocomplete<String>(
                        initialValue:
                            TextEditingValue(text: _cityController.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _kenyaCities;
                          }
                          return _kenyaCities.where((String option) {
                            return option
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _cityController.text = selection;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode,
                            onEditingComplete) {
                          // Keep internal controller in sync
                          controller.addListener(() {
                            _cityController.text = controller.text;
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'County / City',
                              hintText: 'e.g. Nairobi',
                              prefixIcon: const Icon(Icons.location_on_outlined,
                                  size: 18),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 14),
                              suffixIcon: IconButton(
                                icon: _isDetectingLocation
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location,
                                        color: AppColors.primary, size: 18),
                                onPressed: (_isSaving || _isDetectingLocation)
                                    ? null
                                    : _autoDetectGPSLocation,
                                tooltip: 'Auto-detect GPS location',
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter city or county'
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 5: Date of Birth & Age Indicator
                GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateOfBirth,
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now()
                                .subtract(const Duration(days: 365 * 18)),
                          );
                          if (picked != null) {
                            setState(() => _dateOfBirth = picked);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cake_outlined,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Date of Birth: ${DateFormat('yyyy-MM-dd').format(_dateOfBirth)}',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Age: $_calculatedAge yrs',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Section 6: Gender Selection
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: AppConstants.genderOptions
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (val) {
                          if (val != null)
                            setState(() => _selectedGender = val);
                        },
                ),
                const SizedBox(height: 16),

                // Section 7: Bio Field
                TextFormField(
                  controller: _bioController,
                  maxLength: 150,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Bio (Required)',
                    hintText:
                        'Share a little about yourself, hobbies, or what you are looking for...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(Icons.edit_note_outlined),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please add a short bio about yourself';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Section 8: Preferred Contact Method
                DropdownButtonFormField<String>(
                  value: _selectedContactMethod,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Contact Method',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                  items: AppConstants.contactMethods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (val) {
                          if (val != null)
                            setState(() => _selectedContactMethod = val);
                        },
                ),
                const SizedBox(height: 16),

                // Section 9: Private Contact Details (Kenya +254 formatting)
                TextFormField(
                  controller: _contactDetailsController,
                  keyboardType: (_selectedContactMethod == 'WhatsApp' ||
                          _selectedContactMethod == 'Phone Call')
                      ? TextInputType.phone
                      : (_selectedContactMethod == 'Email'
                          ? TextInputType.emailAddress
                          : TextInputType.text),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '$_selectedContactMethod Details',
                    hintText: (_selectedContactMethod == 'WhatsApp' ||
                            _selectedContactMethod == 'Phone Call')
                        ? '0712 345 678 or +254 712 345 678'
                        : (_selectedContactMethod == 'Telegram'
                            ? '@username'
                            : 'name@example.com'),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.primary),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your $_selectedContactMethod details';
                    }
                    if (_selectedContactMethod == 'WhatsApp' ||
                        _selectedContactMethod == 'Phone Call') {
                      if (!_isValidKenyaPhone(v.trim())) {
                        return 'Enter a valid Kenya phone number (e.g. 0712345678 or +254712345678)';
                      }
                    } else if (_selectedContactMethod == 'Email') {
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Contact details are private and never displayed publicly. They are shared only when you connect with a mutual crush.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Section 10: Save & Continue Button
                GradientButton(
                  text: _isSaving ? 'Saving Profile...' : 'Save & Continue',
                  onPressed: _isSaving ? null : _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/gradient_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const ProfileSetupScreen({
    Key? key,
    required this.onSetupComplete,
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
  String _profilePicUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400';
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;

    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _cityController = TextEditingController(text: user?.city ?? 'Nairobi');
    _contactDetailsController = TextEditingController(text: user?.contactDetails ?? '+254712345678');
    if (user != null) {
      _selectedCountry = user.country;
      _selectedGender = user.gender;
      _selectedContactMethod = user.preferredContactMethod;
      _dateOfBirth = user.dateOfBirth;
      if (user.profilePicUrl.isNotEmpty) _profilePicUrl = user.profilePicUrl;
    }
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

  void _autoDetectGPSLocation() async {
    setState(() => _isDetectingLocation = true);
    final result = await LocationService.getCurrentLocation();
    setState(() => _isDetectingLocation = false);

    if (result.success) {
      setState(() {
        _selectedCountry = result.country;
        _cityController.text = result.city;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location detected: ${result.city}, ${result.country}")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? "Failed to detect GPS location.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Avatar Picker
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage: NetworkImage(_profilePicUrl),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username (Public)',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter a username' : null,
                ),
                const SizedBox(height: 16),

                // Country Selection (Required for payments)
                DropdownButtonFormField<String>(
                  value: AppConstants.countries.contains(_selectedCountry) ? _selectedCountry : 'Kenya',
                  decoration: const InputDecoration(
                    labelText: 'Country (Required for Payments)',
                    prefixIcon: Icon(Icons.public),
                  ),
                  items: AppConstants.countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountry = val);
                  },
                ),
                const SizedBox(height: 16),

                // City / County + GPS Detect Button
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'County / City',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter your city' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isDetectingLocation
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, color: AppColors.primary),
                      onPressed: _isDetectingLocation ? null : _autoDetectGPSLocation,
                      tooltip: 'Auto-detect GPS Location',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date of Birth & Age Auto-Calculator
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateOfBirth,
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                    );
                    if (picked != null) {
                      setState(() => _dateOfBirth = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cake, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Date of Birth: ${DateFormat('yyyy-MM-dd').format(_dateOfBirth)}',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Age: $_calculatedAge yrs',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Gender Selection
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: AppConstants.genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGender = val);
                  },
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  maxLength: 150,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio (Max 150 characters)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
                const SizedBox(height: 16),

                // Preferred Contact Method
                DropdownButtonFormField<String>(
                  value: _selectedContactMethod,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Contact Method (Shared on Connection)',
                    prefixIcon: Icon(Icons.contact_phone),
                  ),
                  items: AppConstants.contactMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedContactMethod = val);
                  },
                ),
                const SizedBox(height: 16),

                // Private Contact Details
                TextFormField(
                  controller: _contactDetailsController,
                  decoration: InputDecoration(
                    labelText: '$_selectedContactMethod Details (Private!)',
                    hintText: 'e.g. +254712345678 or @username',
                    prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter contact details' : null,
                ),
                const SizedBox(height: 8),
                Text(
                  '🔒 Contact details are NEVER shown publicly. They are ONLY revealed after a paid connection.',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 28),

                // Save Profile Button
                GradientButton(
                  text: 'Save & Continue',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final current = authProv.currentUser;
                      if (current != null) {
                        final updated = current.copyWith(
                          username: _usernameController.text.trim(),
                          country: _selectedCountry,
                          city: _cityController.text.trim(),
                          dateOfBirth: _dateOfBirth,
                          gender: _selectedGender,
                          bio: _bioController.text.trim(),
                          profilePicUrl: _profilePicUrl,
                          preferredContactMethod: _selectedContactMethod,
                          contactDetails: _contactDetailsController.text.trim(),
                        );
                        authProv.updateUserProfile(updated);
                        widget.onSetupComplete();
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

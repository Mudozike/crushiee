import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _contactDetailsController;

  String _selectedCountry = AppConstants.countries.first;
  String _selectedContactMethod = AppConstants.contactMethods.first;

  @override
  void initState() {
    super.initState();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;

    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _cityController = TextEditingController(text: user?.city ?? 'Nairobi');
    _contactDetailsController =
        TextEditingController(text: user?.contactDetails ?? '');

    if (user != null) {
      if (AppConstants.countries.contains(user.country)) {
        _selectedCountry = user.country;
      }
      if (AppConstants.contactMethods.contains(user.preferredContactMethod)) {
        _selectedContactMethod = user.preferredContactMethod;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final user = authProv.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile Info'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Your Public Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your bio, location, and contact information up to date.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon:
                        Icon(Icons.person_outline, color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a username'
                      : null,
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    prefixIcon: Icon(Icons.notes, color: AppColors.primary),
                    hintText: 'Share a little about yourself...',
                  ),
                ),
                const SizedBox(height: 16),

                // Country Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.public, color: AppColors.primary),
                  ),
                  items: AppConstants.countries.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountry = val);
                  },
                ),
                const SizedBox(height: 16),

                // City
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City / Region',
                    prefixIcon:
                        Icon(Icons.location_city, color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your city'
                      : null,
                ),
                const SizedBox(height: 24),

                Text(
                  'Private Contact Info (Revealed only to connected users)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Preferred Contact Method Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedContactMethod,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Contact Method',
                    prefixIcon: Icon(Icons.contact_phone_outlined,
                        color: AppColors.primary),
                  ),
                  items: AppConstants.contactMethods.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null)
                      setState(() => _selectedContactMethod = val);
                  },
                ),
                const SizedBox(height: 16),

                // Contact Details
                TextFormField(
                  controller: _contactDetailsController,
                  decoration: InputDecoration(
                    labelText: 'Contact Details ($_selectedContactMethod)',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.primary),
                    hintText: _selectedContactMethod == 'WhatsApp'
                        ? '+254712345678'
                        : _selectedContactMethod == 'Telegram'
                            ? '@username'
                            : 'Contact details',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter contact details'
                      : null,
                ),
                const SizedBox(height: 30),

                // Save Button
                GradientButton(
                  text: 'Save Changes',
                  isLoading: authProv.isLoading,
                  onPressed: () async {
                    if (authProv.isLoading) return;
                    if (_formKey.currentState!.validate() && user != null) {
                      final updatedUser = user.copyWith(
                        username: _usernameController.text.trim(),
                        bio: _bioController.text.trim(),
                        country: _selectedCountry,
                        city: _cityController.text.trim(),
                        preferredContactMethod: _selectedContactMethod,
                        contactDetails: _contactDetailsController.text.trim(),
                      );

                      final success =
                          await authProv.updateUserProfile(updatedUser);

                      if (!mounted || !context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(authProv.errorMessage ??
                                'Failed to update profile. Please try again.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    } else if (user == null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No active user session found. Please log in again.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../widgets/gradient_button.dart';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback onPostCreated;

  const CreatePostScreen({
    Key? key,
    required this.onPostCreated,
  }) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCommunity = AppConstants.communities.first['name']!;
  String _selectedLookingFor = AppConstants.lookingForOptions.first;
  String _selectedAvailability = AppConstants.availabilityOptions.first;

  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  RangeValues _ageRange = const RangeValues(21, 35);

  @override
  void initState() {
    super.initState();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;

    _locationController = TextEditingController(
      text: user != null ? '${user.city}, ${user.country}' : 'Nairobi, Kenya',
    );
    _descriptionController = TextEditingController();
    _imageUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final postProv = Provider.of<PostProvider>(context);
    final currentUser = authProv.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title hint banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient.scale(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.edit_note, color: AppColors.primary, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Publicly share what you are looking for.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Community Group Selection
                DropdownButtonFormField<String>(
                  value: _selectedCommunity,
                  decoration: const InputDecoration(
                    labelText: '1. Select Community Group',
                    prefixIcon: Icon(Icons.group_outlined, color: AppColors.primary),
                  ),
                  items: AppConstants.communities.map((c) {
                    final name = c['name']!;
                    return DropdownMenuItem(
                      value: name,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCommunity = val);
                  },
                ),
                const SizedBox(height: 16),

                // 2. Looking For Selection
                DropdownButtonFormField<String>(
                  value: _selectedLookingFor,
                  decoration: const InputDecoration(
                    labelText: '2. What are you Looking For?',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  ),
                  items: AppConstants.lookingForOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(opt),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLookingFor = val);
                  },
                ),
                const SizedBox(height: 16),

                // 3. Location Field
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: '3. Location (City, Area)',
                    prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                    hintText: 'e.g. Westlands, Nairobi',
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter location' : null,
                ),
                const SizedBox(height: 20),

                // 4. Preferred Age Range Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '4. Preferred Age Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      '${_ageRange.start.round()} - ${_ageRange.end.round()} yrs',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                RangeSlider(
                  values: _ageRange,
                  min: 18,
                  max: 70,
                  divisions: 52,
                  activeColor: AppColors.primary,
                  labels: RangeLabels(
                    '${_ageRange.start.round()}',
                    '${_ageRange.end.round()}',
                  ),
                  onChanged: (val) => setState(() => _ageRange = val),
                ),
                const SizedBox(height: 12),

                // 5. Availability Selection
                Text(
                  '5. Availability',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: AppConstants.availabilityOptions.map((opt) {
                    final isSelected = _selectedAvailability == opt;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedAvailability = opt),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.primaryGradient : null,
                            color: isSelected ? null : (isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 6. Description (Unlimited Characters)
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '6. Post Description (Unlimited)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes, color: AppColors.primary),
                    hintText: 'Share details about your plans, expectations or vibes...',
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter a description' : null,
                ),
                const SizedBox(height: 16),

                // 7. Add Image URL (Optional Picture Attachment)
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: '7. Attach Photo (Optional Image URL)',
                    prefixIcon: Icon(Icons.image_outlined, color: AppColors.primary),
                    hintText: 'https://example.com/photo.jpg',
                  ),
                ),
                const SizedBox(height: 28),

                // Publish Button
                GradientButton(
                  text: 'Publish Post',
                  onPressed: () {
                    if (_formKey.currentState!.validate() && currentUser != null) {
                      final newPost = PostModel(
                        id: 'post_${DateTime.now().millisecondsSinceEpoch}',
                        userId: currentUser.id,
                        username: currentUser.username,
                        userProfilePic: currentUser.profilePicUrl,
                        userIsVerified: currentUser.isVerified,
                        userIsOnline: currentUser.isOnline,
                        userLastSeen: currentUser.lastSeen,
                        userCountry: currentUser.country,
                        userCity: currentUser.city,
                        community: _selectedCommunity,
                        lookingFor: _selectedLookingFor,
                        location: _locationController.text.trim(),
                        ageRangeMin: _ageRange.start.round(),
                        ageRangeMax: _ageRange.end.round(),
                        availability: _selectedAvailability,
                        description: _descriptionController.text.trim(),
                        postImageUrl: _imageUrlController.text.trim().isNotEmpty
                            ? _imageUrlController.text.trim()
                            : null,
                        createdAt: DateTime.now(),
                      );

                      postProv.createPost(newPost);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post published successfully!')),
                      );

                      widget.onPostCreated();
                    }
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

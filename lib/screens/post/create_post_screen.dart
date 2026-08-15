import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/boost_post_modal.dart';

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

  XFile? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();

  RangeValues _ageRange = const RangeValues(21, 35);
  bool _wantBoost = false;

  bool get isDatingCommunity {
    final lower = _selectedCommunity.toLowerCase();
    return !lower.contains('advice') && !lower.contains('confession') && !lower.contains('stress');
  }

  @override
  void initState() {
    super.initState();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;

    _locationController = TextEditingController(
      text: user != null ? '${user.city}, ${user.country}' : 'Nairobi, Kenya',
    );
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImageFile = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final postProv = Provider.of<PostProvider>(context);
    final currentUser = authProv.currentUser;

    final bannerText = isDatingCommunity
        ? 'Publicly share what you are looking for.'
        : (_selectedCommunity.toLowerCase().contains('advice')
            ? 'Ask for relationship or social advice from the community.'
            : (_selectedCommunity.toLowerCase().contains('stress')
                ? 'Decompress and share your thoughts or stress with the community.'
                : 'Share an open confession with the community.'));

    final descriptionHint = isDatingCommunity
        ? 'Share details about your plans, expectations or vibes...'
        : (_selectedCommunity.toLowerCase().contains('advice')
            ? 'I have been talking to someone for two weeks and I\'m not sure whether I should ask them out. What do you think?'
            : (_selectedCommunity.toLowerCase().contains('stress')
                ? 'Feeling overwhelmed with work and life this week. How do you all reset?'
                : 'I\'ve had a crush on my best friend for almost a year and they don\'t know...'));

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
                    children: [
                      const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bannerText,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                    if (val != null) {
                      setState(() {
                        _selectedCommunity = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Dating specific field: What are you looking for?
                if (isDatingCommunity) ...[
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
                ],

                // Location Field (Used for both Dating & Advice/Confession)
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: isDatingCommunity ? '3. Location (City, Area)' : '2. Location (City, Area)',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                    hintText: 'e.g. Westlands, Nairobi',
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter location' : null,
                ),
                const SizedBox(height: 20),

                // Dating specific field: Age Range
                if (isDatingCommunity) ...[
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

                  // Dating specific field: Availability
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
                ],

                // Post Content / Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: isDatingCommunity ? '6. Post Description' : '3. Post Content',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes, color: AppColors.primary),
                    hintText: descriptionHint,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter post content' : null,
                ),
                const SizedBox(height: 20),

                // Photo Attachment (Optional)
                Text(
                  isDatingCommunity ? '7. Photo Attachment (Optional)' : '4. Photo Attachment (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                if (_selectedImageFile == null)
                  OutlinedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                    label: const Text(
                      'Select Photo from Local Device',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                else
                  Stack(
                    children: [
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FutureBuilder<dynamic>(
                            future: _selectedImageFile!.readAsBytes(),
                            builder: (ctx, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                );
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: () => setState(() => _selectedImageFile = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Boost Option Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.boostOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.boostOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: AppColors.boostOrange, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Boost Post (KES 49 / 24hrs)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.boostOrange),
                            ),
                            Text(
                              'Pin near top of feed for up to 10x more reach',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _wantBoost,
                        onChanged: (val) => setState(() => _wantBoost = val),
                        activeColor: AppColors.boostOrange,
                      ),
                    ],
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
                        lookingFor: isDatingCommunity ? _selectedLookingFor : _selectedCommunity,
                        location: _locationController.text.trim(),
                        ageRangeMin: isDatingCommunity ? _ageRange.start.round() : 18,
                        ageRangeMax: isDatingCommunity ? _ageRange.end.round() : 99,
                        availability: isDatingCommunity ? _selectedAvailability : 'Anytime',
                        description: _descriptionController.text.trim(),
                        postImageUrl: _selectedImageFile != null ? _selectedImageFile!.path : null,
                        createdAt: DateTime.now(),
                      );

                      postProv.createPost(newPost);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post published successfully!')),
                      );

                      widget.onPostCreated();

                      if (_wantBoost) {
                        BoostPostModal.show(context, newPost, currentUser);
                      }
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

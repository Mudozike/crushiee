import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/boost_post_modal.dart';

class CreatePostScreen extends StatefulWidget {
  final PostModel? existingPost;
  final VoidCallback? onPostCreated;

  const CreatePostScreen({
    Key? key,
    this.existingPost,
    this.onPostCreated,
  }) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedCommunity;
  late String _selectedLookingFor;
  late TextEditingController _locationController;
  late String _selectedAvailability;
  late TextEditingController _descriptionController;

  XFile? _selectedMediaFile;
  String _selectedMediaType = 'none'; // 'none', 'image', 'video'
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();

  late RangeValues _ageRange;
  bool _wantBoost = false;
  bool _isSubmitting = false;
  String _submittingStatus = '';

  bool get isDatingCommunity {
    final lower = _selectedCommunity.toLowerCase();
    return !lower.contains('advice') && !lower.contains('confession') && !lower.contains('stress');
  }

  @override
  void initState() {
    super.initState();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final user = authProv.currentUser;

    _selectedCommunity = widget.existingPost?.community ?? AppConstants.communities.first['name']!;
    _selectedLookingFor = widget.existingPost?.lookingFor ?? AppConstants.lookingForOptions.first;
    _locationController = TextEditingController(
      text: widget.existingPost?.location ?? (user != null ? '${user.city}, ${user.country}' : ''),
    );
    _selectedAvailability = widget.existingPost?.availability ?? AppConstants.availabilityOptions.first;
    _descriptionController = TextEditingController(text: widget.existingPost?.description ?? '');

    _ageRange = RangeValues(
      (widget.existingPost?.ageRangeMin ?? 18).toDouble(),
      (widget.existingPost?.ageRangeMax ?? 35).toDouble(),
    );
    _wantBoost = widget.existingPost?.currentlyBoosted ?? false;

    if (widget.existingPost != null && widget.existingPost!.hasMedia) {
      _selectedMediaType = widget.existingPost!.mediaType;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedMediaFile = image;
          _selectedMediaType = 'image';
        });
      }
    } catch (e) {
      debugPrint('[CREATE_POST] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (video != null) {
        setState(() {
          _selectedMediaFile = video;
          _selectedMediaType = 'video';
        });
      }
    } catch (e) {
      debugPrint('[CREATE_POST] Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  void _showAttachmentOptionsBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Media Attachment',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library, color: AppColors.primary),
                  ),
                  title: const Text('Choose Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select an existing image (JPEG, PNG)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: AppColors.secondary),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture a new photo with camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam, color: Colors.purple),
                  ),
                  title: const Text('Choose Video from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select a video up to 50MB (MP4, MOV)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_call, color: Colors.deepOrange),
                  ),
                  title: const Text('Record Video with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Record a short video clip'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitPost() async {
    if (_isSubmitting) return;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final postProv = Provider.of<PostProvider>(context, listen: false);
    final currentUser = authProv.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User profile not loaded. Please re-login.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submittingStatus = 'Preparing post...';
    });

    try {
      String? permanentMediaUrl = widget.existingPost?.mediaUrl;
      // Sanitize existing post media URL so legacy local cache paths are never propagated
      if (!PostModel.isValidRemoteMediaUrl(permanentMediaUrl)) {
        permanentMediaUrl = null;
      }
      String mediaType = _selectedMediaType;

      // Upload media if a new file was chosen
      if (_selectedMediaFile != null) {
        if (_selectedMediaType == 'image') {
          setState(() => _submittingStatus = 'Uploading photo to Firebase Storage...');
          permanentMediaUrl = await _storageService.uploadPostPhoto(
            userId: currentUser.id,
            file: _selectedMediaFile!,
          );
        } else if (_selectedMediaType == 'video') {
          setState(() => _submittingStatus = 'Uploading video to Firebase Storage...');
          permanentMediaUrl = await _storageService.uploadPostVideo(
            userId: currentUser.id,
            file: _selectedMediaFile!,
          );
        }

        // Strict validation: publication must NOT proceed if remote URL retrieval failed
        if (permanentMediaUrl == null || !PostModel.isValidRemoteMediaUrl(permanentMediaUrl)) {
          throw Exception('Failed to retrieve a valid persistent download URL from Firebase Storage.');
        }
      }

      if (permanentMediaUrl == null) {
        mediaType = 'none';
      }

      if (widget.existingPost != null) {
        setState(() => _submittingStatus = 'Updating post...');
        final updatedPost = widget.existingPost!.copyWith(
          community: _selectedCommunity,
          lookingFor: isDatingCommunity ? _selectedLookingFor : _selectedCommunity,
          location: _locationController.text.trim(),
          ageRangeMin: isDatingCommunity ? _ageRange.start.round() : 18,
          ageRangeMax: isDatingCommunity ? _ageRange.end.round() : 99,
          availability: isDatingCommunity ? _selectedAvailability : 'Anytime',
          description: _descriptionController.text.trim(),
          mediaType: mediaType,
          mediaUrl: permanentMediaUrl,
        );

        final success = await postProv.updatePost(updatedPost, currentUser.id);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post updated successfully!')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update post in Firestore.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        setState(() => _submittingStatus = 'Publishing to Firestore...');
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
          mediaType: mediaType,
          mediaUrl: permanentMediaUrl,
          createdAt: DateTime.now(),
        );

        final success = await postProv.createPost(newPost);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post published successfully to Firestore!')),
            );

            if (widget.onPostCreated != null) {
              widget.onPostCreated!();
            } else {
              Navigator.pop(context);
            }

            if (_wantBoost) {
              BoostPostModal.show(context, newPost, currentUser);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(postProv.fetchError ?? 'Failed to publish post to Firestore.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[CREATE_POST] Error submitting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postProv = Provider.of<PostProvider>(context);

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
        title: Text(widget.existingPost != null ? 'Edit Post' : 'Create Post'),
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
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bannerText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Community Selector
                DropdownButtonFormField<String>(
                  value: _selectedCommunity,
                  decoration: const InputDecoration(
                    labelText: '1. Select Category / Community',
                    prefixIcon: Icon(Icons.tag, color: AppColors.primary),
                  ),
                  items: AppConstants.communities.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['name'],
                      child: Text(c['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCommunity = val);
                  },
                ),
                const SizedBox(height: 20),

                // Dating specific field: Looking For
                if (isDatingCommunity) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedLookingFor,
                    decoration: const InputDecoration(
                      labelText: '2. Looking For',
                      prefixIcon: Icon(Icons.favorite_border, color: AppColors.primary),
                    ),
                    items: AppConstants.lookingForOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLookingFor = val);
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Location field
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.availabilityOptions.map((opt) {
                      final isSelected = _selectedAvailability == opt;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvailability = opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.primaryGradient : null,
                            color: isSelected ? null : (isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.12)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                          ),
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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

                // Photo or Video Attachment (Optional)
                Text(
                  isDatingCommunity ? '7. Media Attachment (Optional)' : '4. Media Attachment (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                if (_selectedMediaFile == null && (widget.existingPost == null || !widget.existingPost!.hasMedia))
                  OutlinedButton.icon(
                    onPressed: _showAttachmentOptionsBottomSheet,
                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.primary),
                    label: const Text(
                      'Attach Photo or Video',
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
                          color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _selectedMediaType == 'video'
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.videocam, color: AppColors.primary, size: 36),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _selectedMediaFile != null
                                            ? _selectedMediaFile!.name
                                            : 'Attached Video',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Ready to upload',
                                        style: TextStyle(fontSize: 11, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                )
                              : (_selectedMediaFile != null
                                  ? FutureBuilder<dynamic>(
                                      future: _selectedMediaFile!.readAsBytes(),
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
                                    )
                                  : (widget.existingPost != null && PostModel.isValidRemoteMediaUrl(widget.existingPost!.mediaUrl)
                                      ? Image.network(
                                          widget.existingPost!.mediaUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : const SizedBox())),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedMediaFile = null;
                              _selectedMediaType = 'none';
                            });
                          },
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

                // Publish / Update Button
                GradientButton(
                  text: (_isSubmitting || postProv.isLoading)
                      ? (_submittingStatus.isNotEmpty ? _submittingStatus : 'Publishing...')
                      : (widget.existingPost != null ? 'Save Changes' : 'Publish Post'),
                  onPressed: (_isSubmitting || postProv.isLoading) ? null : () => _submitPost(),
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

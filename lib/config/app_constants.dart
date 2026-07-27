class AppConstants {
  static const String appName = 'Crushie';
  static const String appTagline = 'Meet people who want the same thing you do.';

  // Initial 12 Communities (Clean, professional, 0 emojis)
  static const List<Map<String, String>> communities = [
    {'name': 'Hook Up', 'icon': '', 'description': 'Quick and passionate connections'},
    {'name': 'Coffee Date', 'icon': '', 'description': 'Casual conversations over coffee'},
    {'name': 'Travel Partner', 'icon': '', 'description': 'Explore the world together'},
    {'name': 'Long-Term Relationship', 'icon': '', 'description': 'Looking for something serious'},
    {'name': 'Casual Meet', 'icon': '', 'description': 'Relaxed and low-pressure hangouts'},
    {'name': 'Tonight Meet', 'icon': '', 'description': 'Available for plans tonight'},
    {'name': 'Quick Meet', 'icon': '', 'description': 'Short and sweet meetups'},
    {'name': 'Weekend Meet', 'icon': '', 'description': 'Weekend fun and adventures'},
    {'name': 'Sugar Daddy / Sugar Mummy', 'icon': '', 'description': 'Mutually beneficial relationships'},
    {'name': 'Advice Zone', 'icon': '', 'description': 'Share and seek relationship advice'},
    {'name': 'Confession Zone', 'icon': '', 'description': 'Safe space to share secrets'},
    {'name': 'Stress Zone', 'icon': '', 'description': 'Vent out and de-stress together'},
  ];

  // Looking For options
  static const List<String> lookingForOptions = [
    'Coffee Date',
    'Travel Partner',
    'Long-Term Relationship',
    'Casual Meet',
    'Hook Up',
    'Weekend Meet',
    'Tonight Meet',
    'Quick Meet',
    'Sugar Daddy',
    'Sugar Mummy',
    'Friendship',
  ];

  // Preferred Contact Methods
  static const List<String> contactMethods = [
    'WhatsApp',
    'Telegram',
    'Phone Call',
    'Email',
  ];

  // Availability Options
  static const List<String> availabilityOptions = [
    'Today',
    'Tonight',
    'Weekend',
    'Anytime',
  ];

  // Gender Options
  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Other',
  ];

  // Common African & Global Countries
  static const List<String> countries = [
    'Kenya',
    'Nigeria',
    'Uganda',
    'Tanzania',
    'Rwanda',
    'South Africa',
    'Ghana',
    'United States',
    'United Kingdom',
    'Other',
  ];

  // Monetization Pricing (KES)
  static const double connectionFeeKES = 50.0;
  static const double premiumMonthlyKES = 200.0;
  static const double verificationFeeKES = 499.0; // Lifetime Verification KES 499
  static const double boost24hKES = 99.0;
  static const double boost7dKES = 200.0;
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Fudron';

  @override
  String exitMessage(Object user) {
    return 'Hello $user';
  }

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get cart => 'Cart';

  @override
  String get orders => 'Orders';

  @override
  String get profile => 'Profile';

  @override
  String get add => 'ADD';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get addItems => 'Add Items';

  @override
  String get viewCart => 'View Cart';

  @override
  String get checkout => 'Checkout';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get proceedToPayment => 'Proceed to Payment';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get billDetails => 'Bill Details';

  @override
  String get itemTotal => 'Item Total';

  @override
  String get deliveryFee => 'Delivery Fee';

  @override
  String get platformFee => 'Platform Fee';

  @override
  String get taxesAndCharges => 'GST / Taxes';

  @override
  String get discount => 'Discount';

  @override
  String get couponDiscount => 'Coupon Discount';

  @override
  String get walletDiscount => 'Wallet Discount';

  @override
  String get packingCharges => 'Packing Charges';

  @override
  String get tip => 'Tip';

  @override
  String get ratings => 'Ratings';

  @override
  String get prepTime => 'Prep Time';

  @override
  String get calories => 'Calories';

  @override
  String get orderPlaced => 'Order placed!';

  @override
  String get orderConfirmed => 'Order confirmed!';

  @override
  String get trackOrder => 'Track Order';

  @override
  String get continueShopping => 'Continue Shopping';

  @override
  String get reorderItems => 'Reorder these items';

  @override
  String get deliveryAddress => 'Delivering to';

  @override
  String get cookingRequests => 'Cooking requests';

  @override
  String get replaceCart => 'Replace Cart?';

  @override
  String get store99 => '149 Meals';

  @override
  String get dining => 'Dining';

  @override
  String get loginTitleNewUser => 'Complete your Profile';

  @override
  String get loginTitleExisting => 'Enter your phone number';

  @override
  String loginSubtitleNewUser(Object phone) {
    return 'Enter your name to register your account with +91 $phone';
  }

  @override
  String get loginSubtitleExisting =>
      'We will send a 4-digit verification code to verify your phone number.';

  @override
  String get fullNameHint => 'Full Name (Required)';

  @override
  String get emailHintOptional => 'Email Address (Optional)';

  @override
  String get alreadyRegistered => 'Already registered? ';

  @override
  String get newToFudron => 'New to Fudron? ';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get continueAndSendOtp => 'Continue & Send OTP';

  @override
  String get continueLabel => 'Continue';

  @override
  String get agreeToTermsPrefix => 'By continuing, you agree to our ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get orDivider => 'OR';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get restaurantsNearYou => 'RESTAURANTS';

  @override
  String get popularBrands => 'POPULAR BRANDS';

  @override
  String restaurantsDeliveringToYou(Object count) {
    return '$count RESTAURANTS DELIVERING TO YOU';
  }

  @override
  String get searchHint => 'Search for \'Pizza\', \'Burger\', \'Fries\'...';

  @override
  String get viewAll => 'View All';

  @override
  String get pillTrending => 'Trending';

  @override
  String get pillNow => 'Now';

  @override
  String get pillStore => 'Store';

  @override
  String get pillBuy1Get1 => 'Buy 1 Get 1';

  @override
  String get pillFree => 'Free';

  @override
  String get pillFreeCaps => 'FREE';

  @override
  String get pillDelivery => 'Delivery';

  @override
  String get pillPureVeg => 'Pure Veg';

  @override
  String get pillNearYou => 'Near You';

  @override
  String get myCart => 'My Cart';

  @override
  String get savedAddresses => 'Saved Addresses';

  @override
  String get addNewAddress => 'Add New Address';

  @override
  String get wallet => 'Wallet';

  @override
  String get coupons => 'Coupons';

  @override
  String get favorites => 'Favorites';

  @override
  String get myOrders => 'My Orders';

  @override
  String get logout => 'Logout';

  @override
  String get selectPaymentMethod => 'Select Payment Method';

  @override
  String totalPayableAmount(Object amount) {
    return 'Total Payable Amount: $amount';
  }

  @override
  String get onlinePayment => 'Online Payment (UPI, Cards, NetBanking)';

  @override
  String get cashOnDelivery => 'Cash on Delivery (COD)';

  @override
  String get fudronWallet => 'Fudron Wallet';

  @override
  String get change => 'Change';

  @override
  String get activeOrders => 'Active Orders';

  @override
  String get pastOrders => 'Past Orders';

  @override
  String get profileSubtitle => 'Manage your account, orders & preferences';

  @override
  String get guestUser => 'Guest User';

  @override
  String get loginPromptOrders =>
      'Log in to unlock orders, addresses & rewards';

  @override
  String get loginPromptDetails =>
      'Sign in to access your orders, saved addresses & profile details.';

  @override
  String get loginSignUp => 'LOG IN / SIGN UP';

  @override
  String get notificationsAndAlerts => 'Notifications & Alerts';

  @override
  String get pushAlertsSubtitle => 'Push alerts & promo settings';

  @override
  String get vegMode => 'Veg Mode';

  @override
  String get vegModeSubtitle => 'Show only vegetarian food items';

  @override
  String get appearanceSettings => 'Appearance Settings';

  @override
  String themeMode(Object mode) {
    return 'Theme: $mode mode';
  }

  @override
  String get appTheme => 'App Theme';

  @override
  String get favoritesSubtitle => 'Your favorite restaurants & dishes';

  @override
  String get viewAllOrders => 'View All Orders';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get refunds => 'Refunds';

  @override
  String get referAndEarn => 'Refer & Earn';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get helpSupportSubtitle => 'FAQs, order refund status & 24/7 support';

  @override
  String get rateApp => 'Rate App';

  @override
  String get rateAppSubtitle => 'Love our app? Leave us a 5-star rating';

  @override
  String get shareApp => 'Share App';

  @override
  String get shareAppSubtitle => 'Share Cravioo food delivery app with friends';

  @override
  String get logOut => 'Log Out';

  @override
  String get logOutConfirm =>
      'Are you sure you want to log out of your account?';

  @override
  String get loggedOutSuccess => 'Logged out successfully';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get logInToAccount => 'Log In to Account';

  @override
  String get unlocksAfterOrders => 'Unlocks after 3 orders';

  @override
  String get viewBalance => 'View Balance';

  @override
  String get emptyCart => 'Your cart is empty';

  @override
  String get noRestaurantsFound => 'No restaurants found';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get pleaseSelectAddress => 'Please select an address';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String activeCoupons(Object count) {
    return '$count Active';
  }

  @override
  String payLaterDue(Object amount) {
    return 'Due: $amount';
  }

  @override
  String payLaterAvailable(Object amount) {
    return 'Available: $amount';
  }

  @override
  String get payLater => 'Pay Later';

  @override
  String clearDueToUseAgain(Object amount) {
    return 'Clear your $amount due to use this again';
  }

  @override
  String availableCreditPayNextTime(Object amount) {
    return 'Available credit: $amount · pay next time';
  }

  @override
  String get paySecurelyRazorpay => 'Pay securely via Razorpay payment gateway';

  @override
  String get payInCashOnDelivery => 'Pay in cash when your food is delivered';

  @override
  String get grandTotal => 'Grand Total';

  @override
  String get addMoney => 'Add Money';

  @override
  String get inclTaxes => 'Incl. taxes';

  @override
  String get gstLabel => 'GST';

  @override
  String get taxesLabel => 'Taxes';

  @override
  String get couldNotCalculateBill =>
      'Could not calculate bill. Please try again.';

  @override
  String get addDeliveryAddressToProceed =>
      'Add a delivery address to place your order.';

  @override
  String get pleaseSelectDeliveryAddress =>
      'Please select a delivery address to proceed.';

  @override
  String get couldNotLoadAddress =>
      'Could not load your saved address. Check your connection and try again.';

  @override
  String insufficientWalletBalance(Object balance, Object needed) {
    return 'Insufficient wallet balance ($balance). Need $needed.';
  }

  @override
  String get cookingRequestHint => 'e.g. Make it less spicy, no onions...';

  @override
  String get saveRequest => 'Save Request';

  @override
  String get editRequest => 'Edit request';

  @override
  String get cookingRequest => 'Cooking request';

  @override
  String get cartEmptySubtitle =>
      'Looks like you haven\'t added anything\nto your cart yet.';

  @override
  String get startShopping => 'Start Shopping';

  @override
  String get explorePopularCategories => 'Explore popular categories';

  @override
  String get categoryMeals => 'Meals';

  @override
  String get categoryPizza => 'Pizza';

  @override
  String get categoryDesserts => 'Desserts';

  @override
  String get categoryBeverages => 'Beverages';

  @override
  String get exclusiveOffers => 'Exclusive offers!';

  @override
  String get exclusiveOffersSubtitle => 'Grab the best deals and save more.';

  @override
  String activeOrdersCount(Object count) {
    return 'Active Orders ($count)';
  }

  @override
  String pastOrdersCount(Object count) {
    return 'Past Orders ($count)';
  }

  @override
  String get notificationsSubtitle => 'Push alerts & promo settings';

  @override
  String savedCount(int count) {
    return '$count Saved';
  }

  @override
  String appearanceThemeMode(String mode) {
    return 'Theme: $mode mode';
  }

  @override
  String referralSubtitle(String code) {
    return 'Code: $code • Share & earn ₹100';
  }

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get cancel => 'Cancel';

  @override
  String get orderStatusAlerts => 'Order Status & Delivery Alerts';

  @override
  String get promoAlerts => 'Promotional Offers & Discounts';

  @override
  String get soundHapticAlerts => 'App Sound & Haptic Alerts';

  @override
  String get pickBrandColor => 'Pick your favorite brand color';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get deleteAccountConfirm =>
      'This will permanently delete your account and all data. This cannot be undone.';

  @override
  String get logOutMessage =>
      'Are you sure you want to log out of your account?';

  @override
  String get deleteAccountMessage =>
      'This permanently deletes your account, orders, addresses, wallet balance and saved data. This cannot be undone.';

  @override
  String get typeDeleteToConfirm => 'Type DELETE to confirm';

  @override
  String get required => 'REQUIRED';

  @override
  String get optional => 'OPTIONAL';

  @override
  String get chooseSize => 'Choose Size';

  @override
  String get selectOneOption => 'Select 1 option';

  @override
  String get includedLabel => 'Included';

  @override
  String get addExtras => 'Add Extras';

  @override
  String get selectAnyYouLike => 'Select any that you like';

  @override
  String addToCartAmount(String amount) {
    return 'Add to Cart • $amount';
  }

  @override
  String updateCartAmount(String amount) {
    return 'Update Cart • $amount';
  }

  @override
  String get ordersSubtitle => 'Track, view and reorder your food';

  @override
  String orderIdLabel(String id) {
    return 'Order ID: $id';
  }

  @override
  String get reorder => 'REORDER';

  @override
  String get trackOrderUpper => 'TRACK ORDER';

  @override
  String orderedAtLabel(String time) {
    return 'Ordered: $time';
  }

  @override
  String get billTotalLabel => 'Bill Total: ';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get cancelledByRestaurant => 'Cancelled by restaurant';

  @override
  String get cancelledByYou => 'Cancelled by you';

  @override
  String get onTheWay => 'On the Way';

  @override
  String get filterAll => 'All';

  @override
  String get filterDelivered => 'Delivered';

  @override
  String get filterCancelled => 'Cancelled';

  @override
  String itemCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }
}

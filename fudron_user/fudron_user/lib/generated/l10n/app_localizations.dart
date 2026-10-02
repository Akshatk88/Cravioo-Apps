import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Fudron'**
  String get appName;

  /// No description provided for @exitMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello {user}'**
  String exitMessage(Object user);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get add;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @addItems.
  ///
  /// In en, this message translates to:
  /// **'Add Items'**
  String get addItems;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @proceedToPayment.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get proceedToPayment;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// No description provided for @billDetails.
  ///
  /// In en, this message translates to:
  /// **'Bill Details'**
  String get billDetails;

  /// No description provided for @itemTotal.
  ///
  /// In en, this message translates to:
  /// **'Item Total'**
  String get itemTotal;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @platformFee.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platformFee;

  /// No description provided for @taxesAndCharges.
  ///
  /// In en, this message translates to:
  /// **'GST / Taxes'**
  String get taxesAndCharges;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @couponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon Discount'**
  String get couponDiscount;

  /// No description provided for @walletDiscount.
  ///
  /// In en, this message translates to:
  /// **'Wallet Discount'**
  String get walletDiscount;

  /// No description provided for @packingCharges.
  ///
  /// In en, this message translates to:
  /// **'Packing Charges'**
  String get packingCharges;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @ratings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratings;

  /// No description provided for @prepTime.
  ///
  /// In en, this message translates to:
  /// **'Prep Time'**
  String get prepTime;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get orderPlaced;

  /// No description provided for @orderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed!'**
  String get orderConfirmed;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get trackOrder;

  /// No description provided for @continueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShopping;

  /// No description provided for @reorderItems.
  ///
  /// In en, this message translates to:
  /// **'Reorder these items'**
  String get reorderItems;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivering to'**
  String get deliveryAddress;

  /// No description provided for @cookingRequests.
  ///
  /// In en, this message translates to:
  /// **'Cooking requests'**
  String get cookingRequests;

  /// No description provided for @replaceCart.
  ///
  /// In en, this message translates to:
  /// **'Replace Cart?'**
  String get replaceCart;

  /// No description provided for @store99.
  ///
  /// In en, this message translates to:
  /// **'149 Meals'**
  String get store99;

  /// No description provided for @dining.
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get dining;

  /// No description provided for @loginTitleNewUser.
  ///
  /// In en, this message translates to:
  /// **'Complete your Profile'**
  String get loginTitleNewUser;

  /// No description provided for @loginTitleExisting.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get loginTitleExisting;

  /// No description provided for @loginSubtitleNewUser.
  ///
  /// In en, this message translates to:
  /// **'Enter your name to register your account with +91 {phone}'**
  String loginSubtitleNewUser(Object phone);

  /// No description provided for @loginSubtitleExisting.
  ///
  /// In en, this message translates to:
  /// **'We will send a 4-digit verification code to verify your phone number.'**
  String get loginSubtitleExisting;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full Name (Required)'**
  String get fullNameHint;

  /// No description provided for @emailHintOptional.
  ///
  /// In en, this message translates to:
  /// **'Email Address (Optional)'**
  String get emailHintOptional;

  /// No description provided for @alreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Already registered? '**
  String get alreadyRegistered;

  /// No description provided for @newToFudron.
  ///
  /// In en, this message translates to:
  /// **'New to Fudron? '**
  String get newToFudron;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @continueAndSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Continue & Send OTP'**
  String get continueAndSendOtp;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @agreeToTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get agreeToTermsPrefix;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @restaurantsNearYou.
  ///
  /// In en, this message translates to:
  /// **'RESTAURANTS'**
  String get restaurantsNearYou;

  /// No description provided for @popularBrands.
  ///
  /// In en, this message translates to:
  /// **'POPULAR BRANDS'**
  String get popularBrands;

  /// No description provided for @restaurantsDeliveringToYou.
  ///
  /// In en, this message translates to:
  /// **'{count} RESTAURANTS DELIVERING TO YOU'**
  String restaurantsDeliveringToYou(Object count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for \'Pizza\', \'Burger\', \'Fries\'...'**
  String get searchHint;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @pillTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get pillTrending;

  /// No description provided for @pillNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get pillNow;

  /// No description provided for @pillStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get pillStore;

  /// No description provided for @pillBuy1Get1.
  ///
  /// In en, this message translates to:
  /// **'Buy 1 Get 1'**
  String get pillBuy1Get1;

  /// No description provided for @pillFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get pillFree;

  /// No description provided for @pillFreeCaps.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get pillFreeCaps;

  /// No description provided for @pillDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get pillDelivery;

  /// No description provided for @pillPureVeg.
  ///
  /// In en, this message translates to:
  /// **'Pure Veg'**
  String get pillPureVeg;

  /// No description provided for @pillNearYou.
  ///
  /// In en, this message translates to:
  /// **'Near You'**
  String get pillNearYou;

  /// No description provided for @myCart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get myCart;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @coupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get coupons;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @totalPayableAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Payable Amount: {amount}'**
  String totalPayableAmount(Object amount);

  /// No description provided for @onlinePayment.
  ///
  /// In en, this message translates to:
  /// **'Online Payment (UPI, Cards, NetBanking)'**
  String get onlinePayment;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery (COD)'**
  String get cashOnDelivery;

  /// No description provided for @fudronWallet.
  ///
  /// In en, this message translates to:
  /// **'Fudron Wallet'**
  String get fudronWallet;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @activeOrders.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrders;

  /// No description provided for @pastOrders.
  ///
  /// In en, this message translates to:
  /// **'Past Orders'**
  String get pastOrders;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, orders & preferences'**
  String get profileSubtitle;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guestUser;

  /// No description provided for @loginPromptOrders.
  ///
  /// In en, this message translates to:
  /// **'Log in to unlock orders, addresses & rewards'**
  String get loginPromptOrders;

  /// No description provided for @loginPromptDetails.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your orders, saved addresses & profile details.'**
  String get loginPromptDetails;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'LOG IN / SIGN UP'**
  String get loginSignUp;

  /// No description provided for @notificationsAndAlerts.
  ///
  /// In en, this message translates to:
  /// **'Notifications & Alerts'**
  String get notificationsAndAlerts;

  /// No description provided for @pushAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push alerts & promo settings'**
  String get pushAlertsSubtitle;

  /// No description provided for @vegMode.
  ///
  /// In en, this message translates to:
  /// **'Veg Mode'**
  String get vegMode;

  /// No description provided for @vegModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show only vegetarian food items'**
  String get vegModeSubtitle;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance Settings'**
  String get appearanceSettings;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme: {mode} mode'**
  String themeMode(Object mode);

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @favoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your favorite restaurants & dishes'**
  String get favoritesSubtitle;

  /// No description provided for @viewAllOrders.
  ///
  /// In en, this message translates to:
  /// **'View All Orders'**
  String get viewAllOrders;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @refunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refunds;

  /// No description provided for @referAndEarn.
  ///
  /// In en, this message translates to:
  /// **'Refer & Earn'**
  String get referAndEarn;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @helpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FAQs, order refund status & 24/7 support'**
  String get helpSupportSubtitle;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @rateAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Love our app? Leave us a 5-star rating'**
  String get rateAppSubtitle;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @shareAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share Cravioo food delivery app with friends'**
  String get shareAppSubtitle;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @logOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get logOutConfirm;

  /// No description provided for @loggedOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get loggedOutSuccess;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @logInToAccount.
  ///
  /// In en, this message translates to:
  /// **'Log In to Account'**
  String get logInToAccount;

  /// No description provided for @unlocksAfterOrders.
  ///
  /// In en, this message translates to:
  /// **'Unlocks after 3 orders'**
  String get unlocksAfterOrders;

  /// No description provided for @viewBalance.
  ///
  /// In en, this message translates to:
  /// **'View Balance'**
  String get viewBalance;

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get emptyCart;

  /// No description provided for @noRestaurantsFound.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found'**
  String get noRestaurantsFound;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @pleaseSelectAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select an address'**
  String get pleaseSelectAddress;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @activeCoupons.
  ///
  /// In en, this message translates to:
  /// **'{count} Active'**
  String activeCoupons(Object count);

  /// No description provided for @payLaterDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {amount}'**
  String payLaterDue(Object amount);

  /// No description provided for @payLaterAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available: {amount}'**
  String payLaterAvailable(Object amount);

  /// No description provided for @payLater.
  ///
  /// In en, this message translates to:
  /// **'Pay Later'**
  String get payLater;

  /// No description provided for @clearDueToUseAgain.
  ///
  /// In en, this message translates to:
  /// **'Clear your {amount} due to use this again'**
  String clearDueToUseAgain(Object amount);

  /// No description provided for @availableCreditPayNextTime.
  ///
  /// In en, this message translates to:
  /// **'Available credit: {amount} · pay next time'**
  String availableCreditPayNextTime(Object amount);

  /// No description provided for @paySecurelyRazorpay.
  ///
  /// In en, this message translates to:
  /// **'Pay securely via Razorpay payment gateway'**
  String get paySecurelyRazorpay;

  /// No description provided for @payInCashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pay in cash when your food is delivered'**
  String get payInCashOnDelivery;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @addMoney.
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get addMoney;

  /// No description provided for @inclTaxes.
  ///
  /// In en, this message translates to:
  /// **'Incl. taxes'**
  String get inclTaxes;

  /// No description provided for @gstLabel.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get gstLabel;

  /// No description provided for @taxesLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get taxesLabel;

  /// No description provided for @couldNotCalculateBill.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate bill. Please try again.'**
  String get couldNotCalculateBill;

  /// No description provided for @addDeliveryAddressToProceed.
  ///
  /// In en, this message translates to:
  /// **'Add a delivery address to place your order.'**
  String get addDeliveryAddressToProceed;

  /// No description provided for @pleaseSelectDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery address to proceed.'**
  String get pleaseSelectDeliveryAddress;

  /// No description provided for @couldNotLoadAddress.
  ///
  /// In en, this message translates to:
  /// **'Could not load your saved address. Check your connection and try again.'**
  String get couldNotLoadAddress;

  /// No description provided for @insufficientWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient wallet balance ({balance}). Need {needed}.'**
  String insufficientWalletBalance(Object balance, Object needed);

  /// No description provided for @cookingRequestHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Make it less spicy, no onions...'**
  String get cookingRequestHint;

  /// No description provided for @saveRequest.
  ///
  /// In en, this message translates to:
  /// **'Save Request'**
  String get saveRequest;

  /// No description provided for @editRequest.
  ///
  /// In en, this message translates to:
  /// **'Edit request'**
  String get editRequest;

  /// No description provided for @cookingRequest.
  ///
  /// In en, this message translates to:
  /// **'Cooking request'**
  String get cookingRequest;

  /// No description provided for @cartEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Looks like you haven\'t added anything\nto your cart yet.'**
  String get cartEmptySubtitle;

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Start Shopping'**
  String get startShopping;

  /// No description provided for @explorePopularCategories.
  ///
  /// In en, this message translates to:
  /// **'Explore popular categories'**
  String get explorePopularCategories;

  /// No description provided for @categoryMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get categoryMeals;

  /// No description provided for @categoryPizza.
  ///
  /// In en, this message translates to:
  /// **'Pizza'**
  String get categoryPizza;

  /// No description provided for @categoryDesserts.
  ///
  /// In en, this message translates to:
  /// **'Desserts'**
  String get categoryDesserts;

  /// No description provided for @categoryBeverages.
  ///
  /// In en, this message translates to:
  /// **'Beverages'**
  String get categoryBeverages;

  /// No description provided for @exclusiveOffers.
  ///
  /// In en, this message translates to:
  /// **'Exclusive offers!'**
  String get exclusiveOffers;

  /// No description provided for @exclusiveOffersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Grab the best deals and save more.'**
  String get exclusiveOffersSubtitle;

  /// No description provided for @activeOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'Active Orders ({count})'**
  String activeOrdersCount(Object count);

  /// No description provided for @pastOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'Past Orders ({count})'**
  String pastOrdersCount(Object count);

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push alerts & promo settings'**
  String get notificationsSubtitle;

  /// No description provided for @savedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Saved'**
  String savedCount(int count);

  /// No description provided for @appearanceThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme: {mode} mode'**
  String appearanceThemeMode(String mode);

  /// No description provided for @referralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Code: {code} • Share & earn ₹100'**
  String referralSubtitle(String code);

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @orderStatusAlerts.
  ///
  /// In en, this message translates to:
  /// **'Order Status & Delivery Alerts'**
  String get orderStatusAlerts;

  /// No description provided for @promoAlerts.
  ///
  /// In en, this message translates to:
  /// **'Promotional Offers & Discounts'**
  String get promoAlerts;

  /// No description provided for @soundHapticAlerts.
  ///
  /// In en, this message translates to:
  /// **'App Sound & Haptic Alerts'**
  String get soundHapticAlerts;

  /// No description provided for @pickBrandColor.
  ///
  /// In en, this message translates to:
  /// **'Pick your favorite brand color'**
  String get pickBrandColor;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all data. This cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @logOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get logOutMessage;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, orders, addresses, wallet balance and saved data. This cannot be undone.'**
  String get deleteAccountMessage;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get typeDeleteToConfirm;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL'**
  String get optional;

  /// No description provided for @chooseSize.
  ///
  /// In en, this message translates to:
  /// **'Choose Size'**
  String get chooseSize;

  /// No description provided for @selectOneOption.
  ///
  /// In en, this message translates to:
  /// **'Select 1 option'**
  String get selectOneOption;

  /// No description provided for @includedLabel.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get includedLabel;

  /// No description provided for @addExtras.
  ///
  /// In en, this message translates to:
  /// **'Add Extras'**
  String get addExtras;

  /// No description provided for @selectAnyYouLike.
  ///
  /// In en, this message translates to:
  /// **'Select any that you like'**
  String get selectAnyYouLike;

  /// No description provided for @addToCartAmount.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart • {amount}'**
  String addToCartAmount(String amount);

  /// No description provided for @updateCartAmount.
  ///
  /// In en, this message translates to:
  /// **'Update Cart • {amount}'**
  String updateCartAmount(String amount);

  /// No description provided for @ordersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track, view and reorder your food'**
  String get ordersSubtitle;

  /// No description provided for @orderIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Order ID: {id}'**
  String orderIdLabel(String id);

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'REORDER'**
  String get reorder;

  /// No description provided for @trackOrderUpper.
  ///
  /// In en, this message translates to:
  /// **'TRACK ORDER'**
  String get trackOrderUpper;

  /// No description provided for @orderedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Ordered: {time}'**
  String orderedAtLabel(String time);

  /// No description provided for @billTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Bill Total: '**
  String get billTotalLabel;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @cancelledByRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by restaurant'**
  String get cancelledByRestaurant;

  /// No description provided for @cancelledByYou.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by you'**
  String get cancelledByYou;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get onTheWay;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get filterDelivered;

  /// No description provided for @filterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get filterCancelled;

  /// No description provided for @itemCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCountPlural(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

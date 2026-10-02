// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Fudron';

  @override
  String exitMessage(Object user) {
    return 'नमस्ते $user';
  }

  @override
  String get home => 'होम';

  @override
  String get search => 'खोजें';

  @override
  String get cart => 'कार्ट';

  @override
  String get orders => 'ऑर्डर';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get add => 'जोड़ें';

  @override
  String get addToCart => 'कार्ट में जोड़ें';

  @override
  String get addItems => 'आइटम जोड़ें';

  @override
  String get viewCart => 'कार्ट देखें';

  @override
  String get checkout => 'चेकआउट';

  @override
  String get placeOrder => 'ऑर्डर करें';

  @override
  String get proceedToPayment => 'भुगतान करें';

  @override
  String get totalPaid => 'कुल भुगतान';

  @override
  String get billDetails => 'बिल विवरण';

  @override
  String get itemTotal => 'आइटम कुल';

  @override
  String get deliveryFee => 'डिलीवरी शुल्क';

  @override
  String get platformFee => 'प्लेटफ़ॉर्म शुल्क';

  @override
  String get taxesAndCharges => 'जीएसटी / कर';

  @override
  String get discount => 'छूट';

  @override
  String get couponDiscount => 'कूपन छूट';

  @override
  String get walletDiscount => 'वॉलेट छूट';

  @override
  String get packingCharges => 'पैकिंग शुल्क';

  @override
  String get tip => 'टिप';

  @override
  String get ratings => 'रेटिंग';

  @override
  String get prepTime => 'तैयारी का समय';

  @override
  String get calories => 'कैलोरी';

  @override
  String get orderPlaced => 'ऑर्डर हो गया!';

  @override
  String get orderConfirmed => 'ऑर्डर की पुष्टि हो गई!';

  @override
  String get trackOrder => 'ऑर्डर ट्रैक करें';

  @override
  String get continueShopping => 'खरीदारी जारी रखें';

  @override
  String get reorderItems => 'इन आइटम को फिर से ऑर्डर करें';

  @override
  String get deliveryAddress => 'डिलीवरी पता';

  @override
  String get cookingRequests => 'खाना बनाने का अनुरोध';

  @override
  String get replaceCart => 'कार्ट बदलें?';

  @override
  String get store99 => '99 स्टोर';

  @override
  String get dining => 'Dining';

  @override
  String get loginTitleNewUser => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get loginTitleExisting => 'अपना फ़ोन नंबर दर्ज करें';

  @override
  String loginSubtitleNewUser(Object phone) {
    return '+91 $phone के साथ अपना खाता पंजीकृत करने के लिए अपना नाम दर्ज करें';
  }

  @override
  String get loginSubtitleExisting =>
      'हम आपके फ़ोन नंबर को सत्यापित करने के लिए 4 अंकों का कोड भेजेंगे।';

  @override
  String get fullNameHint => 'पूरा नाम (आवश्यक)';

  @override
  String get emailHintOptional => 'ईमेल पता (वैकल्पिक)';

  @override
  String get alreadyRegistered => 'पहले से पंजीकृत हैं? ';

  @override
  String get newToFudron => 'Fudron पर नए हैं? ';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get createAccount => 'खाता बनाएं';

  @override
  String get continueAndSendOtp => 'जारी रखें और OTP भेजें';

  @override
  String get continueLabel => 'जारी रखें';

  @override
  String get agreeToTermsPrefix => 'जारी रखकर, आप हमारी ';

  @override
  String get termsOfService => 'सेवा की शर्तों';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get orDivider => 'या';

  @override
  String get continueAsGuest => 'अतिथि के रूप में जारी रखें';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get restaurantsNearYou => 'आपके पास के रेस्टोरेंट';

  @override
  String get popularBrands => 'लोकप्रिय ब्रांड';

  @override
  String restaurantsDeliveringToYou(Object count) {
    return '$count रेस्टोरेंट आपको डिलीवर कर रहे हैं';
  }

  @override
  String get searchHint => '\'पिज़्ज़ा\', \'बर्गर\', \'फ्राइज़\' खोजें...';

  @override
  String get viewAll => 'सभी देखें';

  @override
  String get pillTrending => 'ट्रेंडिंग';

  @override
  String get pillNow => 'अभी';

  @override
  String get pillStore => 'स्टोर';

  @override
  String get pillBuy1Get1 => '1 खरीदें 1';

  @override
  String get pillFree => 'मुफ़्त';

  @override
  String get pillFreeCaps => 'मुफ़्त';

  @override
  String get pillDelivery => 'डिलीवरी';

  @override
  String get pillPureVeg => 'शुद्ध शाकाहारी';

  @override
  String get pillNearYou => 'आपके पास';

  @override
  String get myCart => 'मेरी कार्ट';

  @override
  String get savedAddresses => 'सहेजे गए पते';

  @override
  String get addNewAddress => 'नया पता जोड़ें';

  @override
  String get wallet => 'वॉलेट';

  @override
  String get coupons => 'कूपन';

  @override
  String get favorites => 'पसंदीदा';

  @override
  String get myOrders => 'मेरे ऑर्डर';

  @override
  String get logout => 'लॉग आउट';

  @override
  String get selectPaymentMethod => 'भुगतान विधि चुनें';

  @override
  String totalPayableAmount(Object amount) {
    return 'कुल देय राशि: $amount';
  }

  @override
  String get onlinePayment => 'ऑनलाइन भुगतान (UPI, कार्ड, नेटबैंकिंग)';

  @override
  String get cashOnDelivery => 'कैश ऑन डिलीवरी (COD)';

  @override
  String get fudronWallet => 'Fudron वॉलेट';

  @override
  String get change => 'बदलें';

  @override
  String get activeOrders => 'सक्रिय ऑर्डर';

  @override
  String get pastOrders => 'पिछले ऑर्डर';

  @override
  String get profileSubtitle =>
      'अपना खाता, ऑर्डर और प्राथमिकताएं प्रबंधित करें';

  @override
  String get guestUser => 'अतिथि उपयोगकर्ता';

  @override
  String get loginPromptOrders =>
      'ऑर्डर, पते और रिवॉर्ड अनलॉक करने के लिए लॉग इन करें';

  @override
  String get loginPromptDetails =>
      'अपने ऑर्डर, सहेजे गए पते और प्रोफ़ाइल विवरण एक्सेस करने के लिए साइन इन करें।';

  @override
  String get loginSignUp => 'लॉग इन / साइन अप करें';

  @override
  String get notificationsAndAlerts => 'सूचनाएं और अलर्ट';

  @override
  String get pushAlertsSubtitle => 'पुश अलर्ट और प्रोमो सेटिंग्स';

  @override
  String get vegMode => 'शाकाहारी मोड';

  @override
  String get vegModeSubtitle => 'केवल शाकाहारी भोजन दिखाएं';

  @override
  String get appearanceSettings => 'उपस्थिति सेटिंग्स';

  @override
  String themeMode(Object mode) {
    return 'थीम: $mode मोड';
  }

  @override
  String get appTheme => 'ऐप थीम';

  @override
  String get favoritesSubtitle => 'आपके पसंदीदा रेस्टोरेंट और व्यंजन';

  @override
  String get viewAllOrders => 'सभी ऑर्डर देखें';

  @override
  String get upcoming => 'आगामी';

  @override
  String get completed => 'पूर्ण';

  @override
  String get cancelled => 'रद्द';

  @override
  String get refunds => 'रिफंड';

  @override
  String get referAndEarn => 'रेफ़र करें और कमाएं';

  @override
  String get helpAndSupport => 'सहायता और समर्थन';

  @override
  String get helpSupportSubtitle =>
      'सामान्य प्रश्न, ऑर्डर रिफंड स्थिति और 24/7 सहायता';

  @override
  String get rateApp => 'ऐप को रेट करें';

  @override
  String get rateAppSubtitle => 'हमारा ऐप पसंद है? हमें 5-स्टार रेटिंग दें';

  @override
  String get shareApp => 'ऐप शेयर करें';

  @override
  String get shareAppSubtitle =>
      'Fudron फूड डिलीवरी ऐप दोस्तों के साथ शेयर करें';

  @override
  String get logOut => 'लॉग आउट';

  @override
  String get logOutConfirm =>
      'क्या आप वाकई अपने खाते से लॉग आउट करना चाहते हैं?';

  @override
  String get loggedOutSuccess => 'सफलतापूर्वक लॉग आउट हो गया';

  @override
  String get cancelLabel => 'रद्द करें';

  @override
  String get deleteAccount => 'खाता हटाएं';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get logInToAccount => 'खाते में लॉग इन करें';

  @override
  String get unlocksAfterOrders => '3 ऑर्डर के बाद अनलॉक होता है';

  @override
  String get viewBalance => 'बैलेंस देखें';

  @override
  String get emptyCart => 'आपकी कार्ट खाली है';

  @override
  String get noRestaurantsFound => 'कोई रेस्टोरेंट नहीं मिला';

  @override
  String get somethingWentWrong => 'कुछ गलत हो गया';

  @override
  String get pleaseSelectAddress => 'कृपया एक पता चुनें';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get save => 'सहेजें';

  @override
  String activeCoupons(Object count) {
    return '$count सक्रिय';
  }

  @override
  String payLaterDue(Object amount) {
    return 'देय: $amount';
  }

  @override
  String payLaterAvailable(Object amount) {
    return 'उपलब्ध: $amount';
  }

  @override
  String get payLater => 'पे लेटर';

  @override
  String clearDueToUseAgain(Object amount) {
    return 'इसे फिर से उपयोग करने के लिए अपना $amount देय चुकाएं';
  }

  @override
  String availableCreditPayNextTime(Object amount) {
    return 'उपलब्ध क्रेडिट: $amount · अगली बार भुगतान करें';
  }

  @override
  String get paySecurelyRazorpay =>
      'Razorpay पेमेंट गेटवे से सुरक्षित भुगतान करें';

  @override
  String get payInCashOnDelivery => 'भोजन डिलीवर होने पर नकद भुगतान करें';

  @override
  String get grandTotal => 'कुल योग';

  @override
  String get addMoney => 'पैसे जोड़ें';

  @override
  String get inclTaxes => 'कर सहित';

  @override
  String get gstLabel => 'जीएसटी';

  @override
  String get taxesLabel => 'कर';

  @override
  String get couldNotCalculateBill =>
      'बिल की गणना नहीं हो सकी। कृपया पुनः प्रयास करें।';

  @override
  String get addDeliveryAddressToProceed =>
      'अपना ऑर्डर देने के लिए डिलीवरी पता जोड़ें।';

  @override
  String get pleaseSelectDeliveryAddress =>
      'आगे बढ़ने के लिए कृपया डिलीवरी पता चुनें।';

  @override
  String get couldNotLoadAddress =>
      'आपका सहेजा गया पता लोड नहीं हो सका। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।';

  @override
  String insufficientWalletBalance(Object balance, Object needed) {
    return 'अपर्याप्त वॉलेट बैलेंस ($balance)। आवश्यक: $needed।';
  }

  @override
  String get cookingRequestHint => 'जैसे कि कम तीखा बनाएं, प्याज़ न डालें...';

  @override
  String get saveRequest => 'अनुरोध सहेजें';

  @override
  String get editRequest => 'अनुरोध संपादित करें';

  @override
  String get cookingRequest => 'कुकिंग अनुरोध';

  @override
  String get cartEmptySubtitle =>
      'ऐसा लगता है कि आपने अभी तक\nअपनी कार्ट में कुछ भी नहीं जोड़ा है।';

  @override
  String get startShopping => 'खरीदारी शुरू करें';

  @override
  String get explorePopularCategories => 'लोकप्रिय श्रेणियां देखें';

  @override
  String get categoryMeals => 'भोजन';

  @override
  String get categoryPizza => 'पिज़्ज़ा';

  @override
  String get categoryDesserts => 'मिठाई';

  @override
  String get categoryBeverages => 'पेय पदार्थ';

  @override
  String get exclusiveOffers => 'विशेष ऑफ़र!';

  @override
  String get exclusiveOffersSubtitle => 'बेहतरीन डील पाएं और अधिक बचाएं।';

  @override
  String activeOrdersCount(Object count) {
    return 'सक्रिय ऑर्डर ($count)';
  }

  @override
  String pastOrdersCount(Object count) {
    return 'पिछले ऑर्डर ($count)';
  }

  @override
  String get notificationsSubtitle => 'पुश अलर्ट और प्रोमो सेटिंग्स';

  @override
  String savedCount(int count) {
    return '$count सहेजे गए';
  }

  @override
  String appearanceThemeMode(String mode) {
    return 'थीम: $mode मोड';
  }

  @override
  String referralSubtitle(String code) {
    return 'कोड: $code • शेयर करें और ₹100 कमाएं';
  }

  @override
  String get helpSupport => 'सहायता और समर्थन';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get orderStatusAlerts => 'ऑर्डर स्थिति और डिलीवरी अलर्ट';

  @override
  String get promoAlerts => 'प्रचार ऑफ़र और छूट';

  @override
  String get soundHapticAlerts => 'ऐप ध्वनि और हैप्टिक अलर्ट';

  @override
  String get pickBrandColor => 'अपना पसंदीदा ब्रांड रंग चुनें';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get deleteAccountConfirm =>
      'यह आपके खाते और सभी डेटा को स्थायी रूप से हटा देगा। इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get logOutMessage =>
      'क्या आप वाकई अपने खाते से लॉग आउट करना चाहते हैं?';

  @override
  String get deleteAccountMessage =>
      'यह आपके खाते, ऑर्डर, पते, वॉलेट बैलेंस और सहेजे गए डेटा को स्थायी रूप से हटा देता है। इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get typeDeleteToConfirm => 'पुष्टि के लिए DELETE टाइप करें';

  @override
  String get required => 'आवश्यक';

  @override
  String get optional => 'वैकल्पिक';

  @override
  String get chooseSize => 'आकार चुनें';

  @override
  String get selectOneOption => '1 विकल्प चुनें';

  @override
  String get includedLabel => 'शामिल';

  @override
  String get addExtras => 'अतिरिक्त जोड़ें';

  @override
  String get selectAnyYouLike => 'जो पसंद हो चुनें';

  @override
  String addToCartAmount(String amount) {
    return 'कार्ट में जोड़ें • $amount';
  }

  @override
  String updateCartAmount(String amount) {
    return 'कार्ट अपडेट करें • $amount';
  }

  @override
  String get ordersSubtitle =>
      'अपना खाना ट्रैक करें, देखें और दोबारा ऑर्डर करें';

  @override
  String orderIdLabel(String id) {
    return 'ऑर्डर आईडी: $id';
  }

  @override
  String get reorder => 'दोबारा ऑर्डर करें';

  @override
  String get trackOrderUpper => 'ऑर्डर ट्रैक करें';

  @override
  String orderedAtLabel(String time) {
    return 'ऑर्डर किया: $time';
  }

  @override
  String get billTotalLabel => 'बिल कुल: ';

  @override
  String get statusDelivered => 'डिलीवर किया गया';

  @override
  String get cancelledByRestaurant => 'रेस्टोरेंट द्वारा रद्द';

  @override
  String get cancelledByYou => 'आपके द्वारा रद्द';

  @override
  String get onTheWay => 'रास्ते में';

  @override
  String get filterAll => 'सभी';

  @override
  String get filterDelivered => 'डिलीवर किया गया';

  @override
  String get filterCancelled => 'रद्द';

  @override
  String itemCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम',
      one: '1 आइटम',
    );
    return '$_temp0';
  }
}

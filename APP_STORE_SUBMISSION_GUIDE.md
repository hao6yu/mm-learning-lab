# Apple App Store Submission Fix Guide

## Overview
Your app was rejected because it's missing required information for auto-renewable subscriptions. This guide explains exactly what to fix.

## What Apple Found Missing

### ❌ App Store Connect Metadata Issue
- **Missing**: Functional link to Terms of Use (EULA) in App Description or EULA field

### ✅ What's Already Fixed in Your App Code
After the updates I made, your app now includes:
- ✅ Title of auto-renewing subscription
- ✅ Length of subscription (monthly)  
- ✅ Price of subscription
- ✅ Functional links to Privacy Policy and Terms of Use in the subscription screen
- ✅ Auto-renewal disclosure text

## Required Actions in App Store Connect

### 1. Update App Description
In App Store Connect, update your App Description to include this text:

```
--- ADD THIS TO YOUR APP DESCRIPTION ---

SUBSCRIPTION INFORMATION:
- Monthly subscription: $1.99/month
- First month free trial available
- Payment charged to Apple ID at confirmation of purchase
- Subscription automatically renews unless cancelled at least 24 hours before current period ends
- Manage subscriptions in your Apple ID Account Settings

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://haoyu.io/mm-privacy.html

--- END OF ADDITION ---
```

### 2. Alternative Option: Upload Custom EULA
Instead of using Apple's standard EULA, you can:
1. Upload the `TERMS_OF_USE.md` file I created as a custom EULA in App Store Connect
2. Update the Terms of Use link in your app to point to your hosted version

### 3. Verify Privacy Policy Field
Make sure your Privacy Policy field in App Store Connect contains a valid link or email contact.

## Updated Code Files

I've updated these files in your project:

### 📄 `TERMS_OF_USE.md` (NEW)
- Complete Terms of Use document
- Includes all required subscription terms
- Ready to upload to App Store Connect or host online

### 📄 `PRIVACY_POLICY.md` (UPDATED)
- Added subscription billing reference
- Contact information included

### 📄 `lib/screens/subscription_screen.dart` (UPDATED)
- Added functional links to Terms of Use and Privacy Policy
- Added auto-renewal disclosure text
- Added privacy policy dialog popup
- Apple Store requirement compliance

## Before Resubmitting

### ✅ Checklist
- [ ] Update App Store Connect App Description with subscription info and Terms of Use link
- [ ] Verify Privacy Policy field is filled in App Store Connect  
- [ ] Test the Terms of Use and Privacy Policy links in your app
- [ ] Replace `[your-email@example.com]` with your actual support email
- [ ] Build and test the updated app

### 🧪 Testing
Test these features in your app:
1. Go to subscription screen
2. Tap "Terms of Use" link → should open Apple's EULA page
3. Tap "Privacy Policy" link → should show privacy policy dialog
4. Verify subscription info displays correctly

## Contact Email Update

**IMPORTANT**: Replace `[your-email@example.com]` in these files with your actual support email:
- `TERMS_OF_USE.md`
- `PRIVACY_POLICY.md`
- `lib/screens/subscription_screen.dart`

## Next Steps

1. **Update your support email** in the files mentioned above
2. **Update App Store Connect** with the subscription information and Terms of Use link
3. **Build and test** your app to ensure links work properly
4. **Resubmit** to Apple App Store

## Apple's Requirements Satisfied

After these changes, your app will have:

### ✅ In App Binary:
- Title of auto-renewing subscription ✅
- Length of subscription ✅  
- Price of subscription ✅
- Functional links to privacy policy ✅
- Functional links to Terms of Use (EULA) ✅

### ✅ In App Store Connect Metadata:
- Functional link to Terms of Use in App Description ✅
- Privacy Policy information ✅

## Support

If you need help with any of these steps, refer to:
- [Apple's App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [Subscription Documentation](https://developer.apple.com/documentation/storekit/in-app_purchase)

Your app should be approved after implementing these changes! 🎉 
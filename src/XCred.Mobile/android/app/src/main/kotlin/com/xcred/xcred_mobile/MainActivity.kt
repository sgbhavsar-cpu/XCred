package com.xcred.xcred_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's BiometricPrompt needs a FragmentActivity host — plain FlutterActivity
// can't show the biometric dialog.
class MainActivity : FlutterFragmentActivity()

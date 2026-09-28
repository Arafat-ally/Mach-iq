import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../domain/app_state.dart';

class AdService {
  static bool ready = false;
  static Future<bool> consent() async {
    if (kIsWeb) return false;
    final complete = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          final allowed =
              error == null &&
              await ConsentInformation.instance.canRequestAds();
          if (allowed) {
            await MobileAds.instance.initialize();
            ready = true;
          }
          if (!complete.isCompleted) complete.complete(allowed);
        });
      },
      (error) {
        if (!complete.isCompleted) complete.complete(false);
      },
    );
    return complete.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    );
  }

  static Future<void> privacy() async {
    if (!kIsWeb) await ConsentForm.showPrivacyOptionsForm((error) {});
  }

  static Future<void> rewarded(AppState state) async {
    const unit = String.fromEnvironment('ADMOB_REWARDED_ID');
    if (!state.signedIn ||
        state.isPro ||
        unit.isEmpty ||
        (!ready && !await consent())) {
      return;
    }
    await RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(
              userId: '${state.profile!['user']['id']}',
            ),
          );
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              /* Entitlement changes only after server verification. */
            },
          );
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }
}

class EligibleBanner extends StatefulWidget {
  const EligibleBanner({super.key});
  @override
  State<EligibleBanner> createState() => _EligibleBannerState();
}

class _EligibleBannerState extends State<EligibleBanner> {
  BannerAd? ad;
  bool loaded = false, started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    if (state.isPro || !state.signedIn) {
      ad?.dispose();
      ad = null;
      loaded = false;
      started = false;
      return;
    }
    if (!started) {
      started = true;
      load(state);
    }
  }

  Future<void> load(AppState state) async {
    const unit = String.fromEnvironment('ADMOB_BANNER_ID');
    if (kIsWeb ||
        unit.isEmpty ||
        !await AdService.consent() ||
        !mounted ||
        state.isPro) {
      return;
    }
    ad = BannerAd(
      adUnitId: unit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted && !state.isPro) setState(() => loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      loaded && ad != null && !context.watch<AppState>().isPro
      ? SizedBox(
          height: ad!.size.height.toDouble(),
          width: ad!.size.width.toDouble(),
          child: AdWidget(ad: ad!),
        )
      : const SizedBox.shrink();
}

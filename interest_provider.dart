import 'package:flutter_riverpod/flutter_riverpod.dart';

class InterestNotifier extends StateNotifier<Set<String>> {
  InterestNotifier() : super({});

  void toggleInterest(String interest) {
    if (state.contains(interest)) {
      state = {...state}..remove(interest);
    } else if (state.length < 5) {
      state = {...state, interest};
    }
  }

  void clear() => state = {};
}

final interestProvider = StateNotifierProvider<InterestNotifier, Set<String>>(
  (ref) => InterestNotifier(),
);

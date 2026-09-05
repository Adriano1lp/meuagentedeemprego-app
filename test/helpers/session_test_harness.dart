import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

MemoryTokenStore bindTestTokenStore({String? accessToken}) {
  final store = MemoryTokenStore(accessToken: accessToken);
  bindActiveTokenStore(store);
  return store;
}

ProviderScope testProviderScope({
  required Widget child,
  required TokenStore tokenStore,
  List<Override> overrides = const [],
}) {
  bindActiveTokenStore(tokenStore);
  return ProviderScope(
    overrides: [
      secureTokenStoreProvider.overrideWithValue(tokenStore),
      ...overrides,
    ],
    child: child,
  );
}

bool hiveHoldsPlaintextToken(Box<String> box, String token) {
  for (final key in box.keys) {
    if (key.toString().contains(token)) {
      return true;
    }
    final value = box.get(key);
    if (value != null && value.contains(token)) {
      return true;
    }
  }
  return false;
}

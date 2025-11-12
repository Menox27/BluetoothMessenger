import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/ble_connect_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_screen.dart';
import 'screens/name_setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MessengerApp()));
}

class MessengerApp extends ConsumerWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Bluetooth Messenger',
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: BleConnectScreen.routeName,
      routes: {
        BleConnectScreen.routeName: (_) => const BleConnectScreen(),
        NameSetupScreen.routeName: (_) => const NameSetupScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        JoinScreen.routeName: (_) => const JoinScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == ChatScreen.routeName &&
            settings.arguments is ChatScreenArgs) {
          return MaterialPageRoute(
            builder: (_) =>
                ChatScreen(args: settings.arguments as ChatScreenArgs),
          );
        }
        return null;
      },
    );
  }
}
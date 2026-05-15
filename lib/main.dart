import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'blocs/auth/auth_cubit.dart';
import 'firebase_options.dart';
import 'services/auth_repository.dart';
import 'services/chat_repository.dart';
import 'services/media_service.dart';
import 'services/offline_queue_service.dart';
import 'services/typing_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final firebaseReady = DefaultFirebaseOptions.isConfigured;
  if (firebaseReady) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(MyApp(firebaseReady: firebaseReady));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Chat App - Stage 5',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111318),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/chats': (_) => const ChatListScreen(),
      },
      home: firebaseReady ? const AuthGate() : const FirebaseSetupScreen(),
    );

    if (!firebaseReady) {
      return app;
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => ChatRepository()),
        RepositoryProvider(create: (_) => TypingService()),
        RepositoryProvider(create: (_) => OfflineQueueService()),
        RepositoryProvider(create: (_) => MediaService()),
      ],
      child: BlocProvider(
        create: (context) => AuthCubit(context.read<AuthRepository>()),
        child: app,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state.status == AuthViewStatus.loading ||
            state.status == AuthViewStatus.submitting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.user != null) {
          return const ChatListScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.local_fire_department, size: 48),
              SizedBox(height: 24),
              Text(
                'Firebase setup required',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Text(
                'Create your Firebase project, enable Auth, Firestore, Storage, and Realtime Database, then run with --dart-define values or regenerate lib/firebase_options.dart with flutterfire configure.',
              ),
              SizedBox(height: 16),
              Text(
                'Do not commit google-services.json, GoogleService-Info.plist, or real API values.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

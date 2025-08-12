import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: VCanApp()));
}

class VCanApp extends ConsumerWidget {
  const VCanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = _buildTheme();
    return MaterialApp(
      title: 'VCan',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: _buildTheme(dark: true),
      home: const _AuthGate(),
    );
  }
}

ThemeData _buildTheme({bool dark = false}) {
  const primary = Color(0xFF0097A7);
  const surfaceLight = Color(0xFFF4FAFB);
  const surfaceDark = Color(0xFF102A2E);
  final colorScheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    secondary: const Color(0xFF006D77),
    onSecondary: Colors.white,
    error: Colors.red,
    onError: Colors.white,
    background: dark ? const Color(0xFF08191C) : const Color(0xFFFFFFFF),
    onBackground: dark ? Colors.white : const Color(0xFF102A2E),
    surface: dark ? surfaceDark : surfaceLight,
    onSurface: dark ? Colors.white : const Color(0xFF102A2E),
    tertiary: const Color(0xFF00BCD4),
    onTertiary: Colors.white,
    surfaceVariant: dark ? const Color(0xFF184147) : const Color(0xFFE0F1F3),
    onSurfaceVariant: dark ? Colors.white70 : const Color(0xFF235157),
    outline: dark ? Colors.white24 : const Color(0xFF82B9BF),
    shadow: Colors.black45,
    inverseSurface: primary,
    onInverseSurface: Colors.white,
    inversePrimary: const Color(0xFF006D77),
    scrim: Colors.black54,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.background,
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: dark ? const Color(0xFF13353A) : Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
  return base;
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return const GroupsPage();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Lade ...'),
            ],
          ),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim(),
          );
        } on FirebaseAuthException catch (e2) {
          _error = e2.message;
        }
      } else {
        _error = e.message;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('VCan', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text('Anmelden oder Konto erstellen', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@')) ? 'Gültige E-Mail' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Passwort'),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6) ? 'Min. 6 Zeichen' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Weiter'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => auth.signOut(),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GroupCard(title: 'Willkommen', desc: 'Erste Schritte und Community Richtlinien'),
          _GroupCard(title: 'Mentale Gesundheit', desc: 'Austausch & Unterstützung'),
          _GroupCard(title: 'Wohnraum & Neustart', desc: 'Hilfe bei Wohnungssuche, Umzug, Start'),
          _GroupCard(title: 'Studium & Ausbildung', desc: 'Tipps, Lerngruppen, Orientierung'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final String desc;
  const _GroupCard({required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

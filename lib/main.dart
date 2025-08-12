import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    surface: dark ? surfaceDark : surfaceLight,
    onSurface: dark ? Colors.white : const Color(0xFF102A2E),
    tertiary: const Color(0xFF00BCD4),
    onTertiary: Colors.white,
    surfaceTint: primary,
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
  // Use surface as background base (background deprecated in newer specs)
  scaffoldBackgroundColor: colorScheme.surface,
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
        if (!user.emailVerified && user.email != null) {
          return EmailVerificationPage(user: user);
        }
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

enum _AuthMode { email, phone }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  _AuthMode _mode = _AuthMode.email;
  String? _verificationId;
  bool _codeSent = false;

  Future<void> _submitEmail() async {
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
          if (FirebaseAuth.instance.currentUser != null && !(FirebaseAuth.instance.currentUser!.emailVerified)) {
            await FirebaseAuth.instance.currentUser!.sendEmailVerification();
          }
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

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Telefonnummer eingeben');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        try { await FirebaseAuth.instance.signInWithCredential(cred); } catch (_) {}
      },
      verificationFailed: (e) {
        if (mounted) setState(() { _error = e.message; _loading = false; });
      },
      codeSent: (id, _) {
        if (mounted) setState(() { _verificationId = id; _codeSent = true; _loading = false; });
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
  }

  Future<void> _submitCode() async {
    if (_verificationId == null) return;
    final code = _smsCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Code zu kurz');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code);
      await FirebaseAuth.instance.signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
  _emailCtrl.dispose();
  _passCtrl.dispose();
  _phoneCtrl.dispose();
  _smsCtrl.dispose();
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('E-Mail'),
                          selected: _mode == _AuthMode.email,
                          onSelected: (v) => setState(() { if (v) _mode = _AuthMode.email; }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Telefon'),
                          selected: _mode == _AuthMode.phone,
                          onSelected: (v) => setState(() { if (v) _mode = _AuthMode.phone; }),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_mode == _AuthMode.email) ...[
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
                    ] else ...[
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Telefon (+49...)'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      if (_codeSent)
                        TextFormField(
                          controller: _smsCtrl,
                          decoration: const InputDecoration(labelText: 'SMS Code'),
                          keyboardType: TextInputType.number,
                        ),
                      const SizedBox(height: 24),
                    ],
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () {
                          if (_mode == _AuthMode.email) {
                            _submitEmail();
                          } else {
                            if (_codeSent) {
                              _submitCode();
                            } else {
                              _sendCode();
                            }
                          }
                        },
                        child: _loading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_mode == _AuthMode.email ? 'Weiter' : (_codeSent ? 'Anmelden' : 'Code senden')),
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

final groupsProvider = StreamProvider.autoDispose<List<GroupModel>>((ref) {
  final stream = FirebaseFirestore.instance
      .collection('groups')
      .orderBy('title', descending: false)
      .snapshots();
  return stream.map((snap) => snap.docs
      .map((d) => GroupModel(id: d.id, title: d['title'] ?? 'Ohne Titel', desc: d['desc'] ?? ''))
      .toList());
});

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
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
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(child: Text('Noch keine Gruppen (Firestore).'));
          }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (c, i) {
                final g = groups[i];
                return _GroupCard(title: g.title, desc: g.desc);
              },
            );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }
}

class GroupModel {
  final String id;
  final String title;
  final String desc;
  GroupModel({required this.id, required this.title, required this.desc});
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

class EmailVerificationPage extends StatefulWidget {
  final User user;
  const EmailVerificationPage({super.key, required this.user});
  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _sending = false;
  bool _checking = false;
  String? _msg;

  Future<void> _resend() async {
    setState(() { _sending = true; _msg = null; });
    try {
      await widget.user.sendEmailVerification();
      setState(() { _msg = 'Verifizierungs-E-Mail gesendet.'; });
    } catch (e) {
      setState(() { _msg = 'Fehler: $e'; });
    } finally {
      setState(() { _sending = false; });
    }
  }

  Future<void> _refresh() async {
    setState(() { _checking = true; });
    await widget.user.reload();
    final reloaded = FirebaseAuth.instance.currentUser;
    setState(() { _checking = false; });
    if (reloaded != null && reloaded.emailVerified) {
      // Trigger rebuild of AuthGate by popping a frame
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 56),
                const SizedBox(height: 16),
                Text('Bitte bestätige deine E-Mail Adresse', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(u.email ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                if (_msg != null) ...[
                  Text(_msg!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _sending ? null : _resend,
                      child: _sending ? const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Mail erneut senden'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _checking ? null : _refresh,
                      child: _checking ? const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Aktualisieren'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Abmelden'))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

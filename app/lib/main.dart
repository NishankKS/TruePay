import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/approver.dart';
import 'screens/mission_control.dart';
import 'screens/report.dart';
import 'widgets/theme.dart';

// Firebase web config via --dart-define-from-file=firebase.web.json (see Makefile `web`).
const _opts = FirebaseOptions(
  apiKey: String.fromEnvironment('apiKey'),
  appId: String.fromEnvironment('appId'),
  messagingSenderId: String.fromEnvironment('messagingSenderId'),
  projectId: String.fromEnvironment('projectId'),
  authDomain: String.fromEnvironment('authDomain'),
  storageBucket: String.fromEnvironment('storageBucket'),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _opts);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'IBAN-Wächter',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        onGenerateRoute: (s) => MaterialPageRoute(
          settings: s,
          builder: (_) => AuthGate(
            defaultEmail: s.name == '/approve' ? 'approver@iw-demo.example' : 'operator@iw-demo.example',
            child: switch (s.name) {
              '/approve' => const ApproverScreen(),
              '/report' => const ReportScreen(),
              _ => const MissionControl(),
            },
          ),
        ),
      );
}

class AuthGate extends StatelessWidget {
  final Widget child;
  final String defaultEmail;
  const AuthGate({super.key, required this.child, required this.defaultEmail});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) => snap.data == null ? LoginForm(email: defaultEmail) : child,
      );
}

class LoginForm extends StatefulWidget {
  final String email;
  const LoginForm({super.key, required this.email});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final email = TextEditingController(text: widget.email);
  final pw = TextEditingController();
  String? err;
  Future<void> go() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: pw.text);
    } on FirebaseAuthException catch (e) {
      setState(() => err = e.code);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: card(),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('IBAN-Wächter', style: sans(size: 20, w: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => go()),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: sans(c: cBlock))),
              const SizedBox(height: 16),
              FilledButton(onPressed: go, child: const Text('Sign in')),
            ]),
          ),
        ),
      );
}

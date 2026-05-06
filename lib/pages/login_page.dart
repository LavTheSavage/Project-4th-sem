import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'otp_verify_page.dart';
import 'forgot_password_page.dart';

const Color kPrimary = Color(0xFF1E88E5);
const Color kAccent = Color(0xFFFFC107);
const Color kBackground = Color(0xFFF5F7FA);
const Color kTextDark = Color(0xFF263238);
const Color kSecondary = Color(0xFF90CAF9);

class LoginPage extends StatefulWidget {
  final SupabaseClient client;

  const LoginPage({super.key, required this.client});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordCtrl = TextEditingController();

  Future<void> _reset() async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: _passwordCtrl.text.trim()),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Password updated")));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _reset, child: const Text("Update")),
          ],
        ),
      ),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Register controllers
  final _fullNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _obscureRegConfirm = true;

  bool _showRegisterOnMobile = false;

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await widget.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        final user = response.user!;

        Map<String, dynamic>? profileRes;
        try {
          profileRes = await widget.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();
        } catch (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to fetch user profile"),
              backgroundColor: kAccent,
            ),
          );
          return;
        }
        if (profileRes['is_verified'] != true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please verify your email first"),
              backgroundColor: Colors.orange,
            ),
          );
          return; // Stop login
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: kAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await widget.client.auth.signUp(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text.trim(),
        data: {"full_name": _fullNameController.text.trim()},
      );

      if (res.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyPage(
              email: _regEmailController.text.trim(),
              otpType: OtpType.signup,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- Reusable input decoration ----------------
  InputDecoration _inputStyle({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: kTextDark.withOpacity(.6)),
      prefixIcon: Icon(icon, color: kPrimary),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kSecondary.withOpacity(.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kPrimary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kSecondary.withOpacity(.2)),
      ),
    );
  }

  // // ---------------- Social button ----------------
  // Widget _socialButton(String asset, String text) {
  //   return SizedBox(
  //     height: 48,
  //     width: double.infinity,
  //     child: OutlinedButton.icon(
  //       onPressed: () {},
  //       icon: Image.asset(asset, height: 20),
  //       label: Text(text, style: const TextStyle(fontSize: 14)),
  //       style: OutlinedButton.styleFrom(
  //         side: BorderSide(color: kSecondary.withOpacity(.3)),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         backgroundColor: Colors.white,
  //       ),
  //     ),
  //   );
  // }

  // ---------------- Login form widget ----------------
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome Back",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Sign in to continue",
            style: TextStyle(color: kTextDark.withOpacity(.6)),
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: _emailController,
            validator: (v) => (v == null || v.isEmpty) ? "Enter email" : null,
            decoration: _inputStyle(
              hint: "Your Email",
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (v) =>
                (v == null || v.isEmpty) ? "Enter password" : null,
            decoration: _inputStyle(hint: "Password", icon: Icons.lock_outline)
                .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kPrimary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
          ),

          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                );
              },
              child: Text(
                "Forgot Password?",
                style: TextStyle(color: kPrimary),
              ),
            ),
          ),

          const SizedBox(height: 6),

          const SizedBox(height: 10),

          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Sign In",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 18),
          // Row(
          //   children: [
          //     const Expanded(child: Divider(color: Colors.black12)),
          //     Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 12),
          //       child: Text(
          //         "OR",
          //         style: TextStyle(color: kTextDark.withOpacity(.6)),
          //       ),
          //     ),
          //     const Expanded(child: Divider(color: Colors.black12)),
          //   ],
          // ),

          // const SizedBox(height: 18),
          // _socialButton("assets/icons/google.png", "Login with Google"),
          // const SizedBox(height: 12),
          // _socialButton("assets/icons/facebook.png", "Login with Facebook"),
          // const SizedBox(height: 18),

          // Mobile-only link to go to sign up
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showRegisterOnMobile = true),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: kTextDark.withOpacity(.7)),
                        children: [
                          TextSpan(
                            text: "Register",
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: kTextDark.withOpacity(.7)),
                      children: [
                        TextSpan(
                          text: "Register",
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------- Register form widget ----------------
  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let’s Get Started",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Create a new account",
            style: TextStyle(color: kTextDark.withOpacity(.6)),
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: _fullNameController,
            validator: (v) {
              if (v == null || v.isEmpty) return "Enter your name";
              if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(v)) {
                return "Name must contain letters only";
              }
              return null;
            },
            decoration: _inputStyle(
              hint: "Full Name",
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _regEmailController,
            validator: (v) {
              if (v == null || v.isEmpty) return "Enter email";
              if (!RegExp(r'^[\w.+\-]+@gmail\.com$').hasMatch(v)) {
                return "Only Gmail addresses are allowed";
              }
              return null;
            },
            decoration: _inputStyle(
              hint: "Your Email",
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            validator: (v) =>
                (v == null || v.length < 6) ? "Min 6 characters" : null,
            decoration: _inputStyle(hint: "Password", icon: Icons.lock_outline)
                .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureRegPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kPrimary,
                    ),
                    onPressed: () => setState(
                      () => _obscureRegPassword = !_obscureRegPassword,
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureRegConfirm,
            validator: (v) {
              if (v == null || v.isEmpty) return "Confirm password";
              if (v != _regPasswordController.text) {
                return "Passwords do not match";
              }
              return null;
            },
            decoration:
                _inputStyle(
                  hint: "Password Again",
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureRegConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kPrimary,
                    ),
                    onPressed: () => setState(
                      () => _obscureRegConfirm = !_obscureRegConfirm,
                    ),
                  ),
                ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Sign Up",
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.black12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR",
                  style: TextStyle(color: kTextDark.withOpacity(.6)),
                ),
              ),
              const Expanded(child: Divider(color: Colors.black12)),
            ],
          ),

          // const SizedBox(height: 18),
          // _socialButton("assets/icons/google.png", "Sign Up with Google"),
          // const SizedBox(height: 12),
          // _socialButton("assets/icons/facebook.png", "Sign Up with Facebook"),
          // const SizedBox(height: 18),

          // Mobile-only link to go to login
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showRegisterOnMobile = false),
                    child: RichText(
                      text: TextSpan(
                        text: "Have an account? ",
                        style: TextStyle(color: kTextDark.withOpacity(.7)),
                        children: [
                          TextSpan(
                            text: "Sign In",
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Have an account? ",
                      style: TextStyle(color: kTextDark.withOpacity(.7)),
                      children: [
                        TextSpan(
                          text: "Sign In",
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------- Two-panel desktop layout (left + right) ----------------
  Widget _buildTwoPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 900),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          // LEFT - LOGIN (white card)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 36),
              color: Colors.white,
              child: SingleChildScrollView(child: _buildLoginForm()),
            ),
          ),
          // divider between panels
          Container(width: 2, color: kBackground),
          // RIGHT - REGISTER (light bg)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 36),
              color: kBackground,
              child: SingleChildScrollView(child: _buildRegisterForm()),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Single panel (mobile) ----------------
  Widget _buildSinglePanel(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width - 48; // small padding

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        width: cardWidth.clamp(300.0, 520.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _showRegisterOnMobile
                ? _buildRegisterForm()
                : _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Exit"),
            content: const Text("Do you want to exit the app?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true); // close the dialog
                },
                child: const Text("Yes"),
              ),
            ],
          ),
        );

        if (result ?? false) {
          SystemNavigator.pop(); // closes the app
          return true; // optionally return true if you want to allow pop
        }

        return false; // prevent popping the route
      },

      child: Scaffold(
        backgroundColor: kBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    return Center(child: _buildTwoPanel(context));
                  } else {
                    return _buildSinglePanel(context);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

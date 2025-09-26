import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import 'email_verification_screen.dart';
import 'teacher_profile_completion_screen.dart';
import '../../services/social_auth_service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'student';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.grey50,
              AppTheme.white,
              AppTheme.grey50,
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        
                        // Premium Header
                        RepaintBoundary(child: _buildPremiumHeader()),
                        
                        const SizedBox(height: 24),
                        
                        // Başlık
                        RepaintBoundary(
                          child: Column(
                            children: [
                              Text(
                                'Hesap Oluştur',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Yeni hesabınızı oluşturun',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Ad Soyad Alanı
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                            prefixIcon: Icon(Icons.person_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ad soyad gerekli';
                            }
                            if (value.length < 2) {
                              return 'Ad soyad en az 2 karakter olmalı';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // E-posta Alanı
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'E-posta adresi gerekli';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Geçerli bir e-posta adresi girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Rol Seçimi
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Rol',
                            prefixIcon: Icon(Icons.work_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Öğrenci'),
                            ),
                            DropdownMenuItem(
                              value: 'teacher',
                              child: Text('Öğretmen'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Şifre Alanı
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Şifre gerekli';
                            }
                            if (value.length < 8) {
                              return 'Şifre en az 8 karakter olmalı';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Şifre Tekrar Alanı
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Şifre Tekrar',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Şifre tekrarı gerekli';
                            }
                            if (value != _passwordController.text) {
                              return 'Şifreler eşleşmiyor';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Kayıt Butonu
                        BlocConsumer<AuthBloc, AuthState>(
                          listener: (context, state) {
                            if (state is AuthError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else if (state is AuthUnauthenticated) {
                              // Registration successful, show email verification info
                              final authBloc = context.read<AuthBloc>();
                              final emailVerificationInfo = authBloc.emailVerificationInfo;
                              
                              if (emailVerificationInfo != null) {
                                final mailSent = emailVerificationInfo['mail_sent'] ?? false;
                                final message = emailVerificationInfo['message'] ?? '';
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: mailSent ? Colors.green : Colors.orange,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          builder: (context, state) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.premiumGold,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: state is AuthLoading
                                  ? null
                                  : () async {
                                      if (kDebugMode) {
                                        print('📝 [REGISTER_SCREEN] Register button pressed');
                                        print('📝 [REGISTER_SCREEN] Form validation starting...');
                                      }
                                      
                                      if (_formKey.currentState!.validate()) {
                                        if (kDebugMode) {
                                          print('✅ [REGISTER_SCREEN] Form validation passed');
                                          print('📝 [REGISTER_SCREEN] Name: ${_nameController.text.trim()}');
                                          print('📝 [REGISTER_SCREEN] Email: ${_emailController.text.trim()}');
                                          print('📝 [REGISTER_SCREEN] Role: $_selectedRole');
                                          print('📝 [REGISTER_SCREEN] Password length: ${_passwordController.text.length}');
                                          print('📝 [REGISTER_SCREEN] Password confirmation length: ${_confirmPasswordController.text.length}');
                                        }
                                        
                                        try {
                                          if (kDebugMode) {
                                            print('📝 [REGISTER_SCREEN] Calling AuthBloc.register...');
                                          }
                                          
                                          context.read<AuthBloc>().add(AuthRegisterRequested(
                                                name: _nameController.text.trim(),
                                                email: _emailController.text.trim(),
                                                password: _passwordController.text,
                                                passwordConfirmation:
                                                    _confirmPasswordController.text,
                                                role: _selectedRole,
                                              ));

                                          if (kDebugMode) {
                                            print('✅ [REGISTER_SCREEN] Registration successful!');
                                          }

                                          if (mounted) {
                                            if (kDebugMode) {
                                              print('📱 [REGISTER_SCREEN] Navigating based on role...');
                                            }
                                            
                                            if (_selectedRole == 'teacher') {
                                              // Öğretmen için profil tamamlama sayfasına yönlendir
                                              Navigator.of(context).pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) => TeacherProfileCompletionScreen(
                                                    name: _nameController.text.trim(),
                                                    email: _emailController.text.trim(),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              // Öğrenci için e-posta doğrulama ekranına yönlendir
                                              Navigator.of(context).pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) => EmailVerificationScreen(
                                                    email: _emailController.text.trim(),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (kDebugMode) {
                                            print('❌ [REGISTER_SCREEN] Registration failed: $e');
                                          }
                                          // Hata durumunda AuthBloc zaten AuthError state'ini emit edecek
                                        }
                                      } else {
                                        if (kDebugMode) {
                                          print('❌ [REGISTER_SCREEN] Form validation failed');
                                        }
                                      }
                                    },
                              child: state is AuthLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Kayıt Ol'),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Sosyal Medya Kayıt
                        _buildSocialRegister(),

                        const SizedBox(height: 16),

                        // Giriş Yap Linki
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabınız var mı? ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRegister() {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'veya',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Social Register Buttons
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                icon: Icons.g_mobiledata,
                label: 'Google',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _handleGoogleRegister();
                },
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: _buildSocialButton(
                icon: Icons.facebook,
                label: 'Facebook',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _handleFacebookRegister();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.grey[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleRegister() async {
    try {
      final result = await SocialAuthService.signInWithGoogle();
      
      if (result != null && mounted) {
        final user = result['user'];
        if (user != null) {
          context.read<AuthBloc>().add(AuthUserChanged(User.fromJson(user)));
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Google ile kayıt başarılı!')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER_SCREEN] Google register error: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Google kaydı başarısız: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      }
    }
  }

  Future<void> _handleFacebookRegister() async {
    try {
      // Facebook register implementation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Facebook kaydı yakında aktif olacak!')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REGISTER_SCREEN] Facebook register error: $e');
      }
    }
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        // Premium Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.premiumGold,
                AppTheme.primaryBlue,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.premiumGold.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppTheme.premiumGold, AppTheme.primaryBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'Hesap Oluştur',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          'Yeni hesabınızı oluşturun ve öğrenmeye başlayın',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.grey700,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

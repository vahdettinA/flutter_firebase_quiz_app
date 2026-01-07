import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quiz_app/core/theme/app_colors.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _roomNameController = TextEditingController();
  final _passwordController = TextEditingController();
  double _currentSliderValue = 8;
  bool _isPublic = true;
  bool _isLoading = false;

  Future<void> _createRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    if (_roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir oda ismi girin')),
      );
      return;
    }

    if (!_isPublic && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen oda için bir şifre girin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get User Name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Oyuncu';

      // 2. Generate Room Code
      final roomCode = _generateRoomCode();

      // 3. Create Room Document (Auto ID)
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc();
      await roomRef.set({
        'roomId': roomRef.id,
        'roomCode': roomCode, // Short code for users
        'roomName': _roomNameController.text.trim(),
        'ownerId': user.uid,
        'maxPlayers': _currentSliderValue.toInt(),
        'categories': ['Genel'], // Default category for now
        'isPrivate': !_isPublic,
        'password': _passwordController.text.trim(),
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'currentQuestionIndex': 0,
      });

      // 4. Add Creator to Players Subcollection
      await roomRef.collection('players').doc(user.uid).set({
        'uid': user.uid,
        'name': userName,
        'isReady': true,
        'score': 0,
      });

      if (mounted) {
        context.go('/waiting-room', extra: roomRef.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    // Simple 6-char random code
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(DateTime.now().microsecond % chars.length),
      ),
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.splashGradientStart,
              AppColors.splashGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.textWhite,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Oda Oluştur',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textWhite,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance back button
                    ],
                  ),
                ),

                // Host Avatar
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(
                        bottom: 12,
                      ), // Space for badge
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentColor,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.cardBackground,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'HOST',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.inputBorderOpacity),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Oda İsmi'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _roomNameController,
                        hint: 'Örn. Bilgi Yarışması 🚀',
                        icon: Icons.gamepad_outlined,
                        isPrivate: true,
                      ),

                      const SizedBox(height: 24),

                      _buildLabel('Gizlilik'),
                      const SizedBox(height: 12),
                      // Custom Toggle
                      Container(
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isPublic = true),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isPublic
                                        ? AppColors.progressBackground
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.public,
                                          size: 16,
                                          color: _isPublic
                                              ? AppColors.textWhite
                                              : AppColors.textGrey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Herkese Açık',
                                          style: GoogleFonts.outfit(
                                            color: _isPublic
                                                ? AppColors.textWhite
                                                : AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isPublic = false),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: !_isPublic
                                        ? AppColors.progressBackground
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.verified_user_outlined,
                                          size: 16,
                                          color: !_isPublic
                                              ? AppColors.textWhite
                                              : AppColors.textGrey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Özel',
                                          style: GoogleFonts.outfit(
                                            color: !_isPublic
                                                ? AppColors.textWhite
                                                : AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Conditionally show Password Field
                      if (!_isPublic) ...[
                        const SizedBox(height: 24),
                        _buildLabel('Şifre'),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Gizli anahtar',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          isPrivate: true,
                        ),
                      ],

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Max Oyuncu'),
                          Text(
                            '${_currentSliderValue.toInt()}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.accentColor,
                          inactiveTrackColor: AppColors.sliderTrackInactive,
                          thumbColor: AppColors.sliderThumb,
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16.0,
                          ),
                        ),
                        child: Slider(
                          value: _currentSliderValue,
                          min: 2,
                          max: 10,
                          divisions: 8,
                          onChanged: (double value) {
                            setState(() {
                              _currentSliderValue = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentColor,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: AppColors.shadowColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Oda Oluştur',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.rocket_launch_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPrivate = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.outfit(color: AppColors.textWhite),
        enabled: isPrivate,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppColors.hintText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          prefixIcon: Icon(icon, color: AppColors.inputIconColor),
          suffixIcon: isPassword
              ? const Icon(
                  Icons.visibility_off_outlined,
                  color: AppColors.inputIconColor,
                )
              : null,
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quiz_app/core/theme/app_colors.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _roomCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPublicRooms = true;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom({String? code, String? pwd}) async {
    final roomId = code ?? _roomCodeController.text.trim();
    final password = pwd ?? _passwordController.text.trim();

    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir oda kodu girin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final roomsQuery = await FirebaseFirestore.instance
          .collection('rooms')
          .where('roomCode', isEqualTo: roomId)
          .limit(1)
          .get();

      if (roomsQuery.docs.isEmpty) {
        throw Exception('Oda bulunamadı!');
      }

      final roomDoc = roomsQuery.docs.first;
      final roomRef = roomDoc.reference;
      final roomData = roomDoc.data();

      if (roomData['status'] != 'waiting') {
        throw Exception('Bu oda şu an oyunda!');
      }

      if (roomData['isPrivate'] == true && roomData['password'] != password) {
        throw Exception('Hatalı şifre!');
      }

      final currentPlayers = await roomRef.collection('players').get();
      if (currentPlayers.docs.length >= (roomData['maxPlayers'] ?? 8)) {
        throw Exception('Bu oda dolu!');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userName = userDoc.data()?['name'] ?? 'Oyuncu';

        await roomRef.collection('players').doc(user.uid).set({
          'uid': user.uid,
          'name': userName,
          'isReady': false,
          'score': 0,
        });

        if (mounted) {
          context.go('/waiting-room', extra: roomDoc.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hata: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
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
                          'Odaya Katıl',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Toggle
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorderOpacity),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showPublicRooms = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _showPublicRooms
                                ? AppColors.accentColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Açık Odalar',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: _showPublicRooms
                                  ? Colors.white
                                  : AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showPublicRooms = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_showPublicRooms
                                ? AppColors.accentColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Kod İle Katıl',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: !_showPublicRooms
                                  ? Colors.white
                                  : AppColors.textGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Content
              Expanded(
                child: _showPublicRooms
                    ? _buildPublicRoomsList()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildCodeJoinForm(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicRoomsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .where('isPrivate', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  size: 64,
                  color: AppColors.textGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Açık oda bulunamadı',
                  style: GoogleFonts.outfit(color: AppColors.textGrey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final roomName = data['roomName'] ?? 'İsimsiz Oda';
            final roomCode = data['roomCode'];
            final maxPlayers = data['maxPlayers'] ?? 8;

            String statusText = 'MÜSAİT';
            Color statusColor = AppColors.successColor;
            bool isJoinable = true;

            final status = data['status'];
            final playerCount = data['playerCount'] as int? ?? 0;

            if (status != 'waiting') {
              statusText = 'BAŞLADI';
              statusColor = Colors.orange;
              isJoinable = false;
            } else if (playerCount >= maxPlayers) {
              statusText = 'DOLU';
              statusColor = Colors.redAccent;
              isJoinable = false;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.inputBorderOpacity),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.inputBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.public,
                      color: AppColors.accentColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Kapasite: $playerCount/$maxPlayers',
                              style: GoogleFonts.outfit(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(
                                  51,
                                ), // approx 0.2 opacity
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withAlpha(
                                    128,
                                  ), // approx 0.5 opacity
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isJoinable
                        ? () => _joinRoom(code: roomCode)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentColor,
                      disabledBackgroundColor: AppColors.inputBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'KATIL',
                      style: GoogleFonts.outfit(
                        color: isJoinable ? Colors.white : AppColors.textGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCodeJoinForm() {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            children: const [
              TextSpan(
                text: 'Arenaya\n',
                style: TextStyle(color: AppColors.textWhite),
              ),
              TextSpan(
                text: 'Giriş Yap',
                style: TextStyle(color: AppColors.accentColor),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Savaşmaya hazır mısın? Kurucu tarafından paylaşılan kodu aşağıya gir.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textGrey),
        ),
        const SizedBox(height: 40),
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
              _buildLabel('Oda Kodu'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _roomCodeController,
                hint: 'Kod',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildLabel('Şifre (Opsiyonel)'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _passwordController,
                hint: 'Varsa şifre',
                isPassword: true,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24), // Added SizedBox for spacing
              // QR Scan Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) {
                          bool isDetected = false;
                          return Scaffold(
                            appBar: AppBar(
                              title: const Text('QR Kod Tara'),
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            body: MobileScanner(
                              onDetect: (capture) {
                                if (isDetected) return;
                                final List<Barcode> barcodes = capture.barcodes;
                                for (final barcode in barcodes) {
                                  final code = barcode.rawValue;
                                  if (code != null && code.length == 6) {
                                    isDetected = true;
                                    debugPrint('QR Code found: $code');
                                    _roomCodeController.text = code;
                                    Navigator.of(ctx).pop();
                                    _joinRoom(code: code);
                                    break;
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textWhite,
                    side: const BorderSide(color: AppColors.progressBackground),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'QR Kod Tara',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinRoom,
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
                              'Odaya Gir',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    bool isPassword = false,
    TextAlign textAlign = TextAlign.start,
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
        textAlign: textAlign,
        style: GoogleFonts.outfit(color: AppColors.textWhite),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppColors.hintText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

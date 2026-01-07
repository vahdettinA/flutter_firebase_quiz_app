import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quiz_app/core/services/question_service.dart';
import 'package:quiz_app/core/theme/app_colors.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomId;
  const WaitingRoomScreen({super.key, required this.roomId});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isDisposing = false;

  void _leaveRoom() async {
    if (_isDisposing) return;

    try {
      final roomRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId);
      final roomSnapshot = await roomRef.get();

      if (roomSnapshot.exists) {
        final ownerId = roomSnapshot.data()?['ownerId'];
        final isOwner = ownerId == currentUserId;

        if (isOwner) {
          // If owner, confirm deletion
          if (!mounted) return;
          final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                'Odayı Kapat?',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Oda kurucusu olarak ayrılırsanız oda herkes için kapatılacaktır.',
                style: GoogleFonts.outfit(color: AppColors.textGrey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'İptal',
                    style: GoogleFonts.outfit(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Odayı Kapat',
                    style: GoogleFonts.outfit(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );

          if (shouldDelete == true) {
            // 1. Delete Players
            final playersSnapshot = await roomRef.collection('players').get();
            for (final doc in playersSnapshot.docs) {
              await doc.reference.delete();
            }

            // 2. Delete Answers (if any exist in waiting room context, e.g. from previous games)
            final answersSnapshot = await roomRef.collection('answers').get();
            for (final doc in answersSnapshot.docs) {
              await doc.reference.delete();
            }

            // 3. Delete Room
            await roomRef.delete();
            if (mounted) context.go('/home');
          }
        } else {
          // If player, just leave
          await roomRef.collection('players').doc(currentUserId).delete();
          if (mounted) context.go('/home');
        }
      } else {
        // Room doesn't exist? Just go home.
        if (mounted) context.go('/home');
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  void _copyRoomId(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oda kodu kopyalandı!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentColor),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isDisposing) {
                _isDisposing = true;
                context.go('/home');
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Oda kapatıldı.')));
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          final roomData = snapshot.data!.data() as Map<String, dynamic>;
          final maxPlayers = (roomData['maxPlayers'] as num?)?.toInt() ?? 8;
          final ownerId = roomData['ownerId'];
          final isOwner = ownerId == currentUserId;
          final roomCode = roomData['roomCode']?.toString() ?? widget.roomId;

          // Game Start Listener
          if (roomData['status'] == 'playing') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/game', extra: widget.roomId);
            });
          }

          return Container(
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
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _leaveRoom,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.cardBackground,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textWhite,
                              size: 20,
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              'ODA KODU',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              roomCode,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _copyRoomId(roomCode),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.cardBackground,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.copy,
                              color: AppColors.textWhite,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // QR Code Section
                  if (roomData['roomCode'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: roomCode,
                          version: QrVersions.auto,
                          size: 100.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Players Stream & Bottom Actions
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(widget.roomId)
                          .collection('players')
                          .snapshots(),
                      builder: (context, playersSnapshot) {
                        if (!playersSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final players = playersSnapshot.data!.docs;
                        final playerCount = players.length;

                        // HOST: Update playerCount field in room doc
                        if (isOwner &&
                            roomData['playerCount'] != playerCount &&
                            roomData['status'] == 'waiting') {
                          // Debounce or just update? Optimization: only if diff.
                          // Don't await here to avoid blocking UI, fire and forget.
                          FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(widget.roomId)
                              .update({'playerCount': playerCount});
                        }

                        // Check if I am ready
                        bool amIReady = false;
                        try {
                          final myDoc = players.firstWhere(
                            (d) => d.id == currentUserId,
                          );
                          amIReady =
                              (myDoc.data()
                                  as Map<String, dynamic>)['isReady'] ==
                              true;
                        } catch (_) {}

                        return Column(
                          children: [
                            Text(
                              '$playerCount/$maxPlayers Oyuncu',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1E3D),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.inputBorderOpacity,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    playerCount < 2
                                        ? 'Oyuncu bekleniyor...'
                                        : 'Başlatılabilir!',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Player List
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: maxPlayers, // Show empty slots too
                                itemBuilder: (context, index) {
                                  if (index < players.length) {
                                    final player =
                                        players[index].data()
                                            as Map<
                                              String,
                                              dynamic
                                            >?; // Safe cast
                                    if (player == null) return const SizedBox();

                                    final uid = player['uid'];
                                    final name =
                                        player['name']?.toString() ?? 'Misafir';
                                    final isReady =
                                        player['isReady'] as bool? ?? false;
                                    final isPlayerHost = uid == ownerId;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                      ),
                                      child: _buildPlayerItem(
                                        name:
                                            name +
                                            (uid == currentUserId
                                                ? ' (Sen)'
                                                : ''),
                                        status: isPlayerHost
                                            ? 'Oda Kurucusu'
                                            : (isReady
                                                  ? 'Hazır'
                                                  : 'Hazırlanıyor...'),
                                        isHost: isPlayerHost,
                                        isReady: isReady,
                                      ),
                                    );
                                  } else {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                      ),
                                      child: _buildEmptySlot(),
                                    );
                                  }
                                },
                              ),
                            ),

                            // Bottom Actions (Moved inside)
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  if (isOwner)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final allReady = players.every((doc) {
                                            final data =
                                                doc.data()
                                                    as Map<String, dynamic>;
                                            return data['isReady'] == true;
                                          });

                                          if (!allReady) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Tüm oyuncular hazır olmalı!',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (players.length < 2) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Oyunu başlatmak için en az 2 oyuncu gerekli!',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          bool shouldStart = true;
                                          if (players.length < maxPlayers) {
                                            shouldStart =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    backgroundColor: AppColors
                                                        .cardBackground,
                                                    title: Text(
                                                      'Oda Dolmadı',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    content: Text(
                                                      'Kapasite dolmadı (${players.length}/$maxPlayers). Yine de başlatmak istiyor musunuz?',
                                                      style: GoogleFonts.outfit(
                                                        color:
                                                            AppColors.textGrey,
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                              false,
                                                            ),
                                                        child: Text(
                                                          'Hayır',
                                                          style:
                                                              GoogleFonts.outfit(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                              true,
                                                            ),
                                                        child: Text(
                                                          'Evet',
                                                          style:
                                                              GoogleFonts.outfit(
                                                                color: AppColors
                                                                    .accentColor,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ) ??
                                                false;
                                          }

                                          if (shouldStart) {
                                            final questions =
                                                await QuestionService()
                                                    .getRandomQuestions(5);
                                            final questionsData = questions
                                                .map((q) => q.toMap())
                                                .toList();

                                            await FirebaseFirestore.instance
                                                .collection('rooms')
                                                .doc(widget.roomId)
                                                .update({
                                                  'status': 'playing',
                                                  'questions': questionsData,
                                                  'currentQuestionIndex': 0,
                                                  'gameState': 'answering',
                                                  'startTime':
                                                      FieldValue.serverTimestamp(),
                                                  'gameId': DateTime.now()
                                                      .millisecondsSinceEpoch
                                                      .toString(),
                                                });
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.accentColor,
                                          foregroundColor: Colors.white,
                                          elevation: 8,
                                          shadowColor: AppColors.shadowColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'QUİZİ BAŞLAT',
                                              style: GoogleFonts.outfit(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.play_arrow_rounded,
                                              size: 28,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('rooms')
                                              .doc(widget.roomId)
                                              .collection('players')
                                              .doc(currentUserId)
                                              .update({'isReady': !amIReady});
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: amIReady
                                              ? AppColors.cardBackground
                                              : AppColors.successBackground,
                                          side: BorderSide(
                                            color: amIReady
                                                ? AppColors.textGrey
                                                : AppColors.successColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          amIReady ? "İPTAL ET" : "HAZIRIM",
                                          style: GoogleFonts.outfit(
                                            color: amIReady
                                                ? AppColors.textGrey
                                                : AppColors.successColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _leaveRoom,
                                    child: Text(
                                      'Odadan Ayrıl',
                                      style: GoogleFonts.outfit(
                                        color: AppColors.textGrey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerItem({
    required String name,
    required String status,
    bool isHost = false,
    bool isReady = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHost
              ? AppColors.accentColor
              : AppColors.cardBorderLowOpacity,
          width: isHost ? 1.5 : 1,
        ),
        boxShadow: isHost
            ? [
                const BoxShadow(
                  color: AppColors.accentColorLowOpacity,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHost ? AppColors.accentColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.inputBorder,
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ),
              if (isHost)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'HOST',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ],
                ),
                Text(
                  status,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder, width: 2),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.inputBackground,
            child: Icon(Icons.person_add, color: AppColors.textGreyLowOpacity),
          ),
          const SizedBox(width: 16),
          Text(
            'Oyuncu bekleniyor...',
            style: GoogleFonts.outfit(
              color: AppColors.textGreyLowOpacity,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

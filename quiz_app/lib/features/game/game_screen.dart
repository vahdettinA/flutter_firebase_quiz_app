import 'dart:async';
import 'dart:math' as math; // Added for Bridge calculations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quiz_app/core/services/question_service.dart';
import 'package:quiz_app/core/theme/app_colors.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Local state to track selection before write confirms (optimistic UI)
  String? _selectedOption;
  int _lastSeenQIndex = -1;

  Future<void> _handleExit(String rId, bool isOwner) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(rId);

    try {
      if (isOwner) {
        // Host leaving -> Delete the room AND all subcollections recursively

        // 1. Delete Players
        final playersSnapshot = await roomRef.collection('players').get();
        for (final doc in playersSnapshot.docs) {
          await doc.reference.delete();
        }

        // 2. Delete Answers
        final answersSnapshot = await roomRef.collection('answers').get();
        for (final doc in answersSnapshot.docs) {
          await doc.reference.delete();
        }

        // 3. Delete Room
        await roomRef.delete();
      } else {
        await roomRef.collection('players').doc(user.uid).delete();
      }
      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint("Exit error: $e");
      if (mounted) context.go('/home');
    }
  }

  Future<void> _transferHost(String rId, String newHostId) async {
    await FirebaseFirestore.instance.collection('rooms').doc(rId).update({
      'ownerId': newHostId,
    });
  }

  Future<void> _submitAnswer(
    String rId,
    String gameId,
    int qIndex,
    String answer,
    bool isCorrect,
    DateTime startTime,
    int duration,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Optimistic Update
    setState(() {
      _selectedOption = answer;
    });

    // Score Calculation
    int points = 0;
    if (isCorrect) {
      final now = DateTime.now();
      final elapsedMs = now.difference(startTime).inMilliseconds;
      final totalMs = duration * 1000;
      final ratio = elapsedMs / totalMs;

      // Tiered Scoring:
      // 0.0 - 0.3 (Fastest 30%) -> 100 pts
      // 0.3 - 0.6 (Next 30%)    -> 75 pts
      // 0.6 - 1.0 (Rest)        -> 50 pts

      if (ratio <= 0.3) {
        points = 100;
      } else if (ratio <= 0.6) {
        points = 75;
      } else {
        points = 50;
      }
    }

    final answerRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(rId)
        .collection('answers')
        .doc('${gameId}_q${qIndex}_${user.uid}');

    await answerRef.set({
      'userId': user.uid,
      'gameId': gameId,
      'qIndex': qIndex,
      'answer': answer,
      'isCorrect': isCorrect,
      'points': points,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final rId = GoRouterState.of(context).extra as String?;
    final user = FirebaseAuth.instance.currentUser;

    if (rId == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(rId)
          .snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData || !roomSnap.data!.exists) {
          return const Scaffold(body: Center(child: Text("Room not found")));
        }

        final roomData = roomSnap.data!.data() as Map<String, dynamic>;

        // Clean navigation guard
        if (roomData['status'] == 'waiting') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Check if we are already attempting to go there to avoid loops
              final currentPath = GoRouter.of(
                context,
              ).routerDelegate.currentConfiguration.fullPath;
              if (currentPath != '/waiting-room') {
                context.go('/waiting-room', extra: rId);
              }
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isOwner = roomData['ownerId'] == user.uid;
        final questionsData = List<Map<String, dynamic>>.from(
          roomData['questions'] ?? [],
        );
        final currentQIndex = roomData['currentQuestionIndex'] as int? ?? 0;
        final gameState = roomData['gameState'] as String? ?? 'answering';
        final gameId = roomData['gameId'] as String? ?? '';

        // Reset local selection if new question
        // We'll trust the stream for persistent state, but local selection
        // helps UI responsiveness. We reset it if question changes.
        // Ideally handled by key or separate widget, but safe enough here.

        final currentQuestion =
            questionsData.isNotEmpty && currentQIndex < questionsData.length
            ? Question.fromMap('', questionsData[currentQIndex])
            : null;

        if (currentQIndex != _lastSeenQIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedOption = null;
                _lastSeenQIndex = currentQIndex;
              });
            }
          });
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(rId)
              .collection('players')
              .snapshots(),
          builder: (context, playersSnap) {
            final players = playersSnap.data?.docs ?? [];
            final totalPlayers = players.length;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(rId)
                  .collection('answers')
                  .where('gameId', isEqualTo: gameId)
                  .snapshots(),
              builder: (context, answersSnap) {
                final allAnswers = answersSnap.data?.docs ?? [];

                // --- HOST LOGIC START ---
                if (isOwner) {
                  // 1. Check if everyone answered (Transition Answering -> Revealing)
                  if (gameState == 'answering' && currentQuestion != null) {
                    final roundAnswers = allAnswers
                        .where((d) => d['qIndex'] == currentQIndex)
                        .toList();
                    if (roundAnswers.length >= totalPlayers &&
                        totalPlayers > 0) {
                      Future.delayed(Duration.zero, () {
                        FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(rId)
                            .update({'gameState': 'revealing'});
                      });
                    }
                  }
                  // 2. Auto-Advance Reveal -> Next Question (Handled by _HostAutoAdvancer widget in tree)

                  // 3. Game finished logic handled by index check
                }
                // --- HOST LOGIC END ---

                final myAnswerDocs = allAnswers
                    .where(
                      (d) =>
                          d['userId'] == user.uid &&
                          d['qIndex'] == currentQIndex,
                    )
                    .toList();
                final hasIAnswered = myAnswerDocs.isNotEmpty;

                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) async {
                    if (didPop) return;
                    bool? exit = await _showExitDialog(context);
                    if (exit == true) {
                      await _handleExit(rId, isOwner);
                    }
                  },
                  child: Scaffold(
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
                        child: _buildBody(
                          context,
                          roomData,
                          questionsData,
                          currentQIndex,
                          gameState,
                          isOwner,
                          allAnswers,
                          players,
                          user.uid,
                          rId,
                          gameId,
                          hasIAnswered,
                          currentQuestion,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Oyundan Çık?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Oyun devam ediyor. Ayrılmak istiyor musunuz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hayır', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Evet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Map<String, dynamic> roomData,
    List<Map<String, dynamic>> questionsData,
    int currentQIndex,
    String gameState,
    bool isOwner,
    List<QueryDocumentSnapshot> allAnswers,
    List<QueryDocumentSnapshot> players,
    String myUserId,
    String rId,
    String gameId,
    bool hasIAnswered,
    Question? currentQuestion,
  ) {
    // 1. Result Screen
    if (gameState == 'finished' || currentQIndex >= questionsData.length) {
      return _buildResultScreen(
        context,
        rId,
        gameId,
        questionsData,
        allAnswers,
        players,
        isOwner,
        myUserId,
      );
    }

    // 2. Game Content (Question or Reveal)
    if (currentQuestion == null) return const SizedBox.shrink();

    // Host Auto-Advance Wrapper
    Widget content = Stack(
      children: [
        Column(
          children: [
            _buildBridgeHeader(
              context,
              players,
              allAnswers,
              currentQIndex,
              questionsData.length,
              rId,
              isOwner,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildQuestionCard(currentQuestion),
                    const SizedBox(height: 16),
                    // Timer and Question Counter Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTimer(roomData, currentQuestion.duration),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.cardBorderLowOpacity,
                              ),
                            ),
                            child: Text(
                              "Soru ${currentQIndex + 1}/${questionsData.length}",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildOptionsGrid(
                      rId,
                      gameId,
                      currentQIndex,
                      currentQuestion,
                      hasIAnswered,
                      myUserId,
                      gameState == 'revealing',
                      allAnswers,
                      players,
                      roomData,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Removed _buildFooter call
          ],
        ),
      ],
    );

    if (isOwner && gameState == 'revealing') {
      return _HostAutoAdvancer(
        onTimeout: () async {
          // Advance Question
          int nextIndex = currentQIndex + 1;
          String nextState = (nextIndex >= questionsData.length)
              ? 'finished'
              : 'answering';

          await FirebaseFirestore.instance.collection('rooms').doc(rId).update({
            'currentQuestionIndex': nextIndex,
            'gameState': nextState,
            'startTime': FieldValue.serverTimestamp(),
          });
        },
        child: content,
      );
    }

    return content;
  }

  // --- RESULT SCREEN ---
  Widget _buildResultScreen(
    BuildContext context,
    String rId,
    String gameId,
    List<Map<String, dynamic>> questions,
    List<QueryDocumentSnapshot> allAnswers,
    List<QueryDocumentSnapshot> players,
    bool isOwner,
    String myUserId,
  ) {
    // Calculate Scores & Stats
    final scores = <String, int>{};
    final correctCounts = <String, int>{};

    for (var p in players) {
      scores[p.id] = 0;
      correctCounts[p.id] = 0;
    }

    for (var ans in allAnswers) {
      final uid = ans['userId'] as String;
      final pts = (ans.data() as Map<String, dynamic>).containsKey('points')
          ? (ans['points'] as int)
          : (ans['isCorrect'] == true ? 100 : 0);

      scores[uid] = (scores[uid] ?? 0) + pts;
      if (ans['isCorrect'] == true) {
        correctCounts[uid] = (correctCounts[uid] ?? 0) + 1;
      }
    }

    final sortedPlayers = players.toList()
      ..sort((a, b) {
        final sA = scores[a.id] ?? 0;
        final sB = scores[b.id] ?? 0;
        return sB.compareTo(sA);
      });

    final myRank = sortedPlayers.indexWhere((p) => p.id == myUserId) + 1;
    final myScore = scores[myUserId] ?? 0;
    final myCorrect = correctCounts[myUserId] ?? 0;
    final accuracy = questions.isNotEmpty
        ? ((myCorrect / questions.length) * 100).toInt()
        : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Top Bar
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.arrow_back, color: Colors.white),
                Text(
                  "Sonuçlar",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.share, color: Colors.white),
              ],
            ),
            const SizedBox(height: 30),

            // Avatar & Score Bloom
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.avatarBloom,
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.cardBackground,
                  child: Text(
                    () {
                      if (sortedPlayers.isEmpty) return '?';
                      final data =
                          sortedPlayers.first.data() as Map<String, dynamic>;
                      final name = data['name']?.toString() ?? '?';
                      return name.isEmpty ? '?' : name[0].toUpperCase();
                    }(),
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      myRank == 1 ? "Kazandın!" : "#$myRank. oldun",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "$myScore",
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              "TOPLAM PUAN",
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 30),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildResultStatCard(
                    "Sıralama",
                    "$myRank",
                    Icons.emoji_events,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResultStatCard(
                    "Doğruluk",
                    "%$accuracy",
                    Icons.check_circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Leaderboard
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Lider Tablosu",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: sortedPlayers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = sortedPlayers[index];
                  final pData = p.data() as Map<String, dynamic>;
                  final score = scores[p.id] ?? 0;
                  final isMe = p.id == myUserId;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.splashGradientEnd
                          : AppColors.cardBackgroundMediumOpacity,
                      borderRadius: BorderRadius.circular(16),
                      border: isMe
                          ? Border.all(color: AppColors.accentColor)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          "${index + 1}",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isMe
                              ? AppColors.accentColor
                              : Colors.grey.shade800,
                          child: Text(
                            (pData['name']?.toString() ?? 'U').isNotEmpty
                                ? (pData['name']?.toString() ?? 'U')[0]
                                      .toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pData['name'] ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.whiteLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$score pts",
                            style: const TextStyle(
                              color: AppColors.thinkingStatusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cardBackground,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.home, color: Colors.white),
                    onPressed: () => context.go('/home'),
                  ),
                ),
                const SizedBox(width: 16),
                if (isOwner)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        // Reset room to WAITING state
                        // This will trigger the listener in GameScreen to navigate everyone to WaitingRoom
                        await FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(rId)
                            .update({
                              'status': 'waiting',
                              'gameState': 'waiting',
                              'currentQuestionIndex': 0,
                              'questions': [], // Clear questions to be safe
                              // 'gameId': ... // Keep gameId or leave it, WaitingRoom will set new one on Start
                            });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.replay_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            "Lobiye Dön",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Text(
                        "Yönetici bekleniyor...",
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundMediumOpacity,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // --- GAME UI COMPONENTS ---

  Widget _buildBridgeHeader(
    BuildContext context,
    List<QueryDocumentSnapshot> players,
    List<QueryDocumentSnapshot> allAnswers,
    int currentQIndex,
    int totalQuestions,
    String rId,
    bool isOwner,
  ) {
    // 1. Calculate Scores & Ranks
    final Map<String, int> scores = {};
    for (var p in players) {
      scores[p.id] = 0;
    }
    for (var ans in allAnswers) {
      final uid = ans['userId'] as String;
      final data = ans.data() as Map<String, dynamic>;
      final pts = data.containsKey('points')
          ? (data['points'] as int)
          : (data['isCorrect'] == true ? 100 : 0);
      scores[uid] = (scores[uid] ?? 0) + pts;
    }

    // Sort by score descending
    final sortedPlayers = players.toList()
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    // Group players by score to handle overlaps
    final Map<int, List<QueryDocumentSnapshot>> scoreGroups = {};
    for (var p in sortedPlayers) {
      final s = scores[p.id] ?? 0;
      scoreGroups.putIfAbsent(s, () => []).add(p);
    }

    final maxPossibleScore = totalQuestions * 100;

    return Container(
      height: 240, // Height for the bridge area
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2E3192), // Deep Blue Background
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          // Background Gradient/Image
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4A00E0), Color(0xFF2E3192)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),

          // Settings / Back Buttons (Top Row)
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _showExitDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black26,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.cardBackground,
                        builder: (c) => Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isOwner)
                                ListTile(
                                  leading: const Icon(
                                    Icons.swap_horiz,
                                    color: Colors.white,
                                  ),
                                  title: const Text(
                                    "Yöneticiliği Devret",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    Navigator.pop(c);
                                    _showTransferDialog(context, rId, players);
                                  },
                                ),
                              ListTile(
                                leading: const Icon(
                                  Icons.logout,
                                  color: Colors.redAccent,
                                ),
                                title: const Text(
                                  "Oyundan Çık",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                onTap: () {
                                  Navigator.pop(c);
                                  _handleExit(rId, isOwner);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black26,
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // The Bridge Visualization
          Positioned.fill(
            top: 60,
            bottom: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // The Path Line
                    CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: BridgePainter(),
                    ),
                    // Flag at End
                    Positioned(
                      right: 10,
                      top: constraints.maxHeight * 0.3,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    // Players with Animation and Offset
                    ...scoreGroups.entries.expand((entry) {
                      final groupScore = entry.key;
                      final groupPlayers = entry.value;

                      return groupPlayers.asMap().entries.map((playerEntry) {
                        final indexInGroup = playerEntry.key;
                        final p = playerEntry.value;

                        // Calculate base position
                        double progress = maxPossibleScore > 0
                            ? (groupScore / maxPossibleScore).clamp(0.0, 1.0)
                            : 0.0;

                        double w = constraints.maxWidth - 40;
                        double h = constraints.maxHeight;

                        double t = progress;
                        double xBase = 20 + w * t; // Linear X

                        // Bezier Y Calculation (must match painter)
                        // B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
                        // P0=(0, 0.8h), P1=(0.5w, 0.2h), P2=(w, 0.5h) -- approximated X->t mapping
                        double yFactor =
                            math.pow(1 - t, 2) * 0.8 +
                            2 * (1 - t) * t * 0.2 +
                            math.pow(t, 2) * 0.5;
                        double yBase = h * yFactor;

                        // Apply Offsets for Overlap
                        // Stagger them slightly up/down and left/right
                        double xOffset = 0;
                        double yOffset = 0;

                        if (groupPlayers.length > 1) {
                          // Example stagger:
                          // 0 -> (0,0)
                          // 1 -> (10, -20)
                          // 2 -> (-10, -20)
                          // 3 -> (20, -40) ...
                          int row = (indexInGroup + 1) ~/ 2;
                          bool right = indexInGroup % 2 != 0;

                          yOffset = row * -35.0; // Stack upwards
                          xOffset = (row * 10.0) * (right ? 1 : -1);

                          // If too many, maybe random or just stack vertically
                        }

                        double finalX = xBase + xOffset;
                        double finalY =
                            yBase + yOffset - 55; // -55 to sit on line

                        final name =
                            (p.data() as Map<String, dynamic>)['name'] ?? 'P';
                        final isMe =
                            p.id == FirebaseAuth.instance.currentUser?.uid;

                        // Rank needs to be calculated globally
                        final globalRank =
                            sortedPlayers.indexWhere((sp) => sp.id == p.id) + 1;

                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          left: finalX - 20, // Center
                          top: finalY,
                          child: Column(
                            children: [
                              Text(
                                "$globalRank.",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  shadows: [
                                    const Shadow(
                                      color: Colors.black,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withAlpha(51),
                                  border: Border.all(
                                    color: isMe
                                        ? AppColors.accentColor
                                        : Colors.white,
                                    width: isMe ? 2 : 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isMe
                                      ? AppColors.accentColor
                                      : AppColors.cardBackground,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                "$groupScore",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    const Shadow(
                                      color: Colors.black,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- GAME UI COMPONENTS ---

  /* 
     Replaced original _buildHeader with _buildBridgeHeader 
  */

  void _showTransferDialog(
    BuildContext context,
    String rId,
    List<QueryDocumentSnapshot> players,
  ) {
    final others = players
        .where((p) => p.id != FirebaseAuth.instance.currentUser?.uid)
        .toList();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          "Yöneticiliği Devret",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: others.isEmpty
              ? const Text(
                  "Başka oyuncu yok.",
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: others.length,
                  itemBuilder: (ctx, i) {
                    final p = others[i];
                    final data = p.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(
                        data['name'] ?? 'User',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        await _transferHost(rId, p.id);
                        if (context.mounted) Navigator.pop(c);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question q) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.questionCardGradientStart,
            AppColors.questionCardGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            q.category,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            q.question,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(
    String rId,
    String gameId,
    int qIndex,
    Question q,
    bool hasAnswered,
    String uId,
    bool isRevealing,
    List<QueryDocumentSnapshot> allAnswers,
    List<QueryDocumentSnapshot> players,
    Map<String, dynamic>? roomData,
  ) {
    // Process answers for revealing
    Map<String, List<String>> optionPlayerAvatars = {};
    if (isRevealing) {
      // Map option key -> List of user Initials/Avatars
      for (var ans in allAnswers) {
        if (ans['qIndex'] == qIndex && ans['gameId'] == gameId) {
          final chosen = ans['answer'] as String;
          final userId = ans['userId'] as String;

          // Find player name
          final playerDoc = players.where((p) => p.id == userId).firstOrNull;
          final userData = playerDoc?.data() as Map<String, dynamic>?;
          final name = userData?['name']?.toString() ?? '?';

          optionPlayerAvatars.putIfAbsent(chosen, () => []).add(name);
        }
      }
    }

    final startTime =
        (roomData?['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: q.options.entries.map((e) {
          final key = e.key;
          final text = e.value;

          bool isSelected =
              hasAnswered && (_selectedOption == key); // Local state check?
          // Actually if hasAnswered is true, we should check firestore data?
          // But for speed, let's assume _selectedOption tracks it for me.
          // Or better, query firestore for *my* answer.
          // We have `hasAnswered`. We can find *what* I answered.
          // Let's refine `isSelected` using allAnswers for robust re-entry.
          if (hasAnswered) {
            final myAns = allAnswers
                .where((a) => a['userId'] == uId && a['qIndex'] == qIndex)
                .firstOrNull;
            if (myAns != null) {
              isSelected = myAns['answer'] == key;
            }
          } else if (_selectedOption != null) {
            isSelected = _selectedOption == key;
          }

          // Colors
          Color borderColor = AppColors.cardBorderLowOpacity;
          Color bgColor = AppColors.headerPillBackground;

          if (isRevealing) {
            final isCorrectOption = key == q.correctOption;
            if (isCorrectOption) {
              borderColor = AppColors.successColor;
              bgColor = AppColors.successHighlight;
            } else if (isSelected) {
              borderColor = Colors.redAccent;
              bgColor = AppColors.errorHighlight;
            } else {
              bgColor = AppColors.cardBackgroundMediumOpacity; // Dim others
            }
          } else {
            if (isSelected) {
              borderColor = AppColors.accentColor;
              bgColor = AppColors.optionSelectedTint;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GestureDetector(
              onTap: (hasAnswered || isRevealing || _selectedOption != null)
                  ? null
                  : () {
                      _submitAnswer(
                        rId,
                        gameId,
                        qIndex,
                        key,
                        key == q.correctOption,
                        startTime,
                        q.duration,
                      );
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || (isRevealing && key == q.correctOption)
                        ? 2
                        : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRevealing && key == q.correctOption
                                ? AppColors.successColor
                                : (isSelected
                                      ? AppColors.accentColor
                                      : Colors.transparent),
                            border: Border.all(color: AppColors.greyMedium),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            key.toUpperCase(),
                            style: TextStyle(
                              color:
                                  (isSelected ||
                                      (isRevealing && key == q.correctOption))
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isRevealing && key == q.correctOption)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.successColor,
                          ),
                        if (isRevealing && isSelected && key != q.correctOption)
                          const Icon(Icons.cancel, color: Colors.redAccent),
                      ],
                    ),

                    // Show avatars of people who picked this
                    if (isRevealing && optionPlayerAvatars.containsKey(key))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 40),
                        child: Wrap(
                          spacing: 4,
                          children: optionPlayerAvatars[key]!
                              .map(
                                (name) => Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.whiteMedium,
                                  ),
                                  child: CircleAvatar(
                                    radius: 8,
                                    backgroundColor: AppColors.accentColor,
                                    child: Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimer(Map<String, dynamic> roomData, int duration) {
    final startTime = roomData['startTime'] as Timestamp?;
    if (startTime == null) return const SizedBox.shrink();

    return _GameTimer(
      startTime: startTime.toDate(),
      durationSeconds: duration,
      onTimeUp: () {
        // If I haven't answered, force submit null or just disable?
        // Actually the host handles state transition.
        // We just disable UI locally via expiry check.
        setState(
          () {},
        ); // specific rebuild for timer expiry handled inside timer?
        // Actually if time is up, we should disable options.
        // But options disable themselves if we just rebuild.
      },
    );
  }
}

class _HostAutoAdvancer extends StatefulWidget {
  final VoidCallback onTimeout;
  final Widget child;
  const _HostAutoAdvancer({required this.onTimeout, required this.child});
  @override
  State<_HostAutoAdvancer> createState() => _HostAutoAdvancerState();
}

class _HostAutoAdvancerState extends State<_HostAutoAdvancer> {
  @override
  void initState() {
    super.initState();
    // Shorter reveal time for better flow
    Future.delayed(const Duration(seconds: 4), widget.onTimeout);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _GameTimer extends StatefulWidget {
  final DateTime startTime;
  final int durationSeconds;
  final VoidCallback onTimeUp;

  const _GameTimer({
    required this.startTime,
    required this.durationSeconds,
    required this.onTimeUp,
  });

  @override
  State<_GameTimer> createState() => _GameTimerState();
}

class _GameTimerState extends State<_GameTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.durationSeconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final diff = now.difference(widget.startTime).inSeconds;
      final left = widget.durationSeconds - diff;

      if (left <= 0) {
        _timer.cancel();
        if (mounted) {
          setState(() => _remaining = 0);
          widget.onTimeUp();
        }
      } else {
        if (mounted) setState(() => _remaining = left);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_GameTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _timer.cancel();
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground, // Dark background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentColor.withAlpha(128),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppColors.accentColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            "$_remaining",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16, // Smaller font
              fontWeight: FontWeight.bold,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          Text(
            "s",
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class BridgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(128)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Starting point (Left, near bottom)
    path.moveTo(0, h * 0.8);

    // Quadratic Bezier to proper "Hill" shape
    // Control Point at (0.5w, 0.2h) -> High middle
    // End Point at (w, 0.5h) -> Mid right
    path.quadraticBezierTo(w * 0.5, h * 0.2, w, h * 0.5);

    canvas.drawPath(path, paint);

    // Draw dots or ticks? Optional.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:go_router/go_router.dart';
import 'package:quiz_app/features/auth/login_screen.dart';
import 'package:quiz_app/features/auth/register_screen.dart';
import 'package:quiz_app/features/game/game_screen.dart';
import 'package:quiz_app/features/home/home_screen.dart';
import 'package:quiz_app/features/room/create_room_screen.dart';
import 'package:quiz_app/features/room/join_room_screen.dart';
import 'package:quiz_app/features/room/waiting_room_screen.dart';
import 'package:quiz_app/features/splash/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/create-room',
      builder: (context, state) => const CreateRoomScreen(),
    ),
    GoRoute(
      path: '/join-room',
      builder: (context, state) => const JoinRoomScreen(),
    ),
    GoRoute(
      path: '/waiting-room',
      builder: (context, state) {
        final roomId = state.extra as String? ?? '';
        return WaitingRoomScreen(roomId: roomId);
      },
    ),
    GoRoute(path: '/game', builder: (context, state) => const GameScreen()),
  ],
);

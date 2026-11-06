import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/feedback/presentation/feedback_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/guide/presentation/guide_profile_screen.dart';
import '../features/guide/presentation/guide_resume_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/interview/data/interview_models.dart';
import '../features/interview/presentation/generating_screen.dart';
import '../features/interview/presentation/interview_screen.dart';
import '../features/interview/presentation/job_profile_screen.dart';
import '../features/interview/presentation/report_list_screen.dart';
import '../features/interview/presentation/result_screen.dart';
import '../features/interview/presentation/room_screen.dart';
import '../features/jobs/presentation/applications_screen.dart';
import '../features/jobs/presentation/invites_screen.dart';
import '../features/jobs/presentation/job_detail_screen.dart';
import '../features/jobs/presentation/jobs_screen.dart';
import '../features/messages/presentation/chat_screen.dart';
import '../features/messages/presentation/message_center_screen.dart';
import '../features/messages/presentation/system_notice_screen.dart';
import '../features/profile/presentation/checkin_screen.dart';
import '../features/profile/presentation/profile_edit_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/questions/presentation/favorite_list_screen.dart';
import '../features/questions/presentation/question_detail_screen.dart';
import '../features/questions/presentation/questions_screen.dart';
import '../features/resume/presentation/resume_detail_screen.dart';
import '../features/resume/presentation/resume_list_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/warmup/presentation/improv_screen.dart';
import '../features/warmup/presentation/speed_screen.dart';
import 'shell/main_shell.dart';

/// 根导航器 Key：版本更新弹窗等需要挂在路由之上弹出时使用。
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 全局路由表。
///
/// 未登录 → `/`(开屏) → `/login`
/// 登录后 → `/guide/1` → `/guide/2` → `/home`
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/guide/1', builder: (_, _) => const GuideProfileScreen()),
      GoRoute(path: '/guide/2', builder: (_, _) => const GuideResumeScreen()),
      GoRoute(path: '/warmup/improv', builder: (_, _) => const ImprovScreen()),
      GoRoute(path: '/warmup/speed', builder: (_, _) => const SpeedScreen()),
      GoRoute(
        path: '/question/:id',
        builder: (_, state) => QuestionDetailScreen(
          questionId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/interview/job-profile',
        builder: (_, _) => const JobProfileScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => JobProfileEditScreen(
              profile: state.extra is JobProfileM
                  ? state.extra as JobProfileM
                  : null,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/interview/reports',
        builder: (_, _) => const ReportListScreen(),
      ),
      GoRoute(
        path: '/interview/generating',
        builder: (_, state) => GeneratingScreen(
          sessionId:
              int.tryParse(state.uri.queryParameters['sessionId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/room/:sessionId',
        builder: (_, state) => RoomScreen(
          sessionId: int.tryParse(state.pathParameters['sessionId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/result/:reportId',
        builder: (_, state) => ResultScreen(
          reportId: int.tryParse(state.pathParameters['reportId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/jobs/applications',
        builder: (_, _) => const ApplicationsScreen(),
      ),
      GoRoute(path: '/jobs/invites', builder: (_, _) => const InvitesScreen()),
      GoRoute(
        path: '/jobs/:id',
        builder: (_, state) => JobDetailScreen(
          jobId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/profile/messages',
        builder: (_, _) => const MessageCenterScreen(),
      ),
      GoRoute(
        path: '/profile/resumes',
        builder: (_, _) => const ResumeListScreen(),
      ),
      GoRoute(
        path: '/profile/resumes/:id',
        builder: (_, state) => ResumeDetailScreen(
          resumeId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/profile/favorites',
        builder: (_, _) => const FavoriteListScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/profile/checkin',
        builder: (_, _) => const CheckinScreen(),
      ),
      GoRoute(
        path: '/profile/feedback',
        builder: (_, _) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/profile/messages/system',
        builder: (_, _) => const SystemNoticeScreen(),
      ),
      GoRoute(
        path: '/profile/messages/chat/:talentId',
        builder: (_, state) => ChatScreen(
          talentId: int.tryParse(state.pathParameters['talentId'] ?? '') ?? 0,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/questions',
                builder: (_, _) => const QuestionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/interview',
                builder: (_, _) => const InterviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/jobs', builder: (_, _) => const JobsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

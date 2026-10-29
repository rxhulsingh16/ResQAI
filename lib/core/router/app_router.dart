import 'dart:convert';
import 'package:flutter/material.dart';
import '../../features/home/home_portal_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/citizen/citizen_dashboard_screen.dart';
import '../../features/citizen/citizen_sos_screen.dart';
import '../../features/citizen/citizen_reports_screen.dart';
import '../../features/citizen/citizen_new_report_screen.dart';
import '../../features/citizen/citizen_report_detail_screen.dart';
import '../../features/citizen/citizen_shelters_screen.dart';
import '../../features/citizen/citizen_alerts_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/citizen/citizen_campaigns_screen.dart';
import '../../features/citizen/citizen_donations_screen.dart';
import '../../features/citizen/citizen_help_screen.dart';
import '../../features/citizen/citizen_help_request_screen.dart';
import '../../features/citizen/citizen_missing_person_screen.dart';
import '../../features/map/disaster_map_screen.dart';
import '../../features/transparency/transparency_overview_screen.dart';
import '../../features/transparency/transparency_organizations_screen.dart';
import '../../features/transparency/transparency_funds_screen.dart';
import '../../features/transparency/transparency_areas_screen.dart';
import '../../features/intelligence/intelligence_dashboard_screen.dart';
import '../../features/intelligence/risk_forecast_screen.dart';
import '../../features/intelligence/needs_forecast_screen.dart';
import '../../features/intelligence/resource_optimization_screen.dart';
import '../../features/intelligence/anomalies_screen.dart';
import '../../features/intelligence/scenario_simulation_screen.dart';
import '../../features/intelligence/model_performance_screen.dart';
import '../../features/ngo/ngo_dashboard_screen.dart';
import '../../features/ngo/ngo_management_screen.dart';
import '../../features/volunteer/volunteer_dashboard_screen.dart';
import '../../features/volunteer/volunteer_portal_screen.dart';
import '../../features/government/government_command_centre_screen.dart';
import '../../features/government/government_financial_screen.dart';
import '../../features/government/government_operations_screen.dart';
import '../../features/medical/medical_dashboard_screen.dart';
import '../../features/rescue/responder_dashboard_screen.dart';
import '../../features/preparedness/preparedness_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../data/services/storage_service.dart';
import '../../shared/models/user_model.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/widgets/access_denied_screen.dart';
import '../auth/app_bootstrap_gate.dart';

class AppRoutes {
  // Public
  static const String bootstrap = '/bootstrap';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String transparency = '/transparency';
  static const String transparencyOrgs = '/transparency/organizations';
  static const String transparencyFunds = '/transparency/funds';
  static const String transparencyAreas = '/transparency/areas';
  static const String preparedness = '/preparedness';
  static const String disasterMap = '/disaster-map';

  // Citizen
  static const String citizenDashboard = '/citizen/dashboard';
  static const String citizenHelp = '/citizen/help';
  static const String citizenHelpRequest = '/citizen/help/request';
  static const String citizenMissingPerson = '/citizen/missing-person';
  static const String citizenMap = '/citizen/map';
  static const String citizenAlerts = '/citizen/alerts';
  static const String citizenSos = '/citizen/sos';
  static const String citizenReports = '/citizen/reports';
  static const String citizenNewReport = '/citizen/reports/new';
  static const String citizenReportDetail = '/citizen/reports/:id';
  static const String citizenAssistance = '/citizen/assistance';
  static const String citizenShelters = '/citizen/shelters';
  static const String citizenNotifications = '/citizen/notifications';
  static const String profile = '/profile';
  static const String citizenProfile = '/citizen/profile';
  static const String citizenEmergencyContacts = '/citizen/emergency-contacts';
  static const String citizenDonate = '/citizen/donate';
  static const String citizenDonations = '/citizen/donations';

  // NGO
  static const String ngoDashboard = '/ngo/dashboard';
  static const String ngoOperations = '/ngo/operations';
  static const String ngoCampaigns = '/ngo/campaigns';
  static const String ngoDonations = '/ngo/donations';
  static const String ngoFinances = '/ngo/finances';
  static const String ngoExpenses = '/ngo/expenses';
  static const String ngoResources = '/ngo/resources';
  static const String ngoBeneficiaries = '/ngo/beneficiaries';
  static const String ngoCoverageMap = '/ngo/coverage-map';
  static const String ngoVolunteers = '/ngo/volunteers';
  static const String ngoVerification = '/ngo/verification';
  static const String ngoReports = '/ngo/reports';

  // Volunteer
  static const String volunteerDashboard = '/volunteer/dashboard';
  static const String volunteerOpportunities = '/volunteer/opportunities';
  static const String volunteerTasks = '/volunteer/tasks';
  static const String volunteerTaskDetail = '/volunteer/tasks/:id';
  static const String volunteerMap = '/volunteer/map';
  static const String volunteerAvailability = '/volunteer/availability';
  static const String volunteerTraining = '/volunteer/training';
  static const String volunteerDonations = '/volunteer/donations';
  static const String volunteerHistory = '/volunteer/history';
  static const String volunteerProfile = '/volunteer/profile';

  // Government
  static const String governmentDashboard = '/government/dashboard';
  static const String governmentCommandCentre = '/government/command-centre';
  static const String governmentIncidents = '/government/incidents';
  static const String governmentIncidentDetail = '/government/incidents/:id';
  static const String governmentVerification = '/government/verification';
  static const String governmentDispatch = '/government/dispatch';
  static const String governmentTeams = '/government/teams';
  static const String governmentHospitals = '/government/hospitals';
  static const String governmentShelters = '/government/shelters';
  static const String governmentResources = '/government/resources';
  static const String governmentReliefPrograms = '/government/relief-programs';
  static const String governmentFinancialTransparency = '/government/financial-transparency';
  static const String governmentAreaCoverage = '/government/area-coverage';
  static const String governmentAnalytics = '/government/analytics';
  static const String governmentAudit = '/government/audit';
  static const String governmentAnnouncements = '/government/announcements';

  // Responder & Medical
  static const String responderDashboard = '/responder/dashboard';
  static const String responderAssignments = '/responder/assignments';
  static const String responderAssignmentDetail = '/responder/assignments/:id';
  static const String responderMap = '/responder/map';
  static const String medicalDashboard = '/medical/dashboard';
  static const String medicalRequests = '/medical/requests';
  static const String medicalHospitals = '/medical/hospitals';
  static const String medicalResources = '/medical/resources';

  // AI Intelligence
  static const String intelligenceDashboard = '/intelligence/dashboard';
  static const String intelligenceRiskForecast = '/intelligence/risk-forecast';
  static const String intelligenceImpactAnalysis = '/intelligence/impact-analysis';
  static const String intelligenceNeedsForecast = '/intelligence/needs-forecast';
  static const String intelligenceResourceOptimization = '/intelligence/resource-optimization';
  static const String intelligenceAnomalies = '/intelligence/anomalies';
  static const String intelligenceSimulation = '/intelligence/simulation';
  static const String intelligenceModelPerformance = '/intelligence/model-performance';
}

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isNavigatingToSos = false;

  /// Prevents duplicate stacked pushes when user taps SOS repeatedly
  static void navigateToSos(BuildContext context) {
    if (_isNavigatingToSos) return;
    final current = ModalRoute.of(context)?.settings.name;
    if (current == AppRoutes.citizenSos) return;
    _isNavigatingToSos = true;
    Navigator.pushNamed(context, AppRoutes.citizenSos).then((_) {
      _isNavigatingToSos = false;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      _isNavigatingToSos = false;
    });
  }

  static String getHomeRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.citizen:
        return AppRoutes.citizenDashboard;
      case UserRole.volunteer:
        return AppRoutes.volunteerDashboard;
      case UserRole.ngoLead:
        return AppRoutes.ngoDashboard;
      case UserRole.govtOfficial:
      case UserRole.incidentCommander:
      case UserRole.admin:
        return AppRoutes.governmentCommandCentre;
      case UserRole.rescueTeam:
      case UserRole.fieldResponder:
        return AppRoutes.responderDashboard;
      case UserRole.doctor:
        return AppRoutes.medicalDashboard;
      case UserRole.analyst:
        return AppRoutes.intelligenceDashboard;
      default:
        return AppRoutes.citizenDashboard;
    }
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? AppRoutes.home);
    final path = uri.path;

    // PRD v3.0 Section 8 & SEC-1, SEC-2, SEC-6: Route Guards and Role Separation
    // 1. Identify if route is Public or Protected
    final isPublicRoute = path == AppRoutes.bootstrap ||
        path == AppRoutes.home ||
        path == AppRoutes.login ||
        path == AppRoutes.register ||
        path == AppRoutes.forgotPassword ||
        path == AppRoutes.transparency ||
        path.startsWith('/transparency/') ||
        path == AppRoutes.preparedness ||
        path == AppRoutes.disasterMap ||
        path == AppRoutes.citizenMap ||
        path == AppRoutes.citizenSos;

    // Load active session from storage
    UserModel? currentUser;
    try {
      final userJson = StorageService.getString(StorageService.keyCurrentUser);
      if (userJson != null && userJson.isNotEmpty) {
        currentUser = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      }
    } catch (_) {}

    // If route is private and user is not authenticated, redirect to login
    if (!isPublicRoute && currentUser == null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AuthScreen(isRegisterMode: false),
      );
    }

    // Role-based privilege enforcement for authenticated users
    if (currentUser != null) {
      final role = currentUser.role;

      // Government & Intelligence modules require Incident Commander / Official / Admin
      if (path.startsWith('/government') || path.startsWith('/intelligence')) {
        final isGovtAuthorized = role == UserRole.incidentCommander ||
            role == UserRole.govtOfficial ||
            role == UserRole.analyst ||
            role == UserRole.admin;
        if (!isGovtAuthorized) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AccessDeniedScreen(
              attemptedPath: path,
              requiredRoleDescription: 'Incident Commander / Government SDRF Authority',
            ),
          );
        }
      }

      // NGO modules require NGO Lead or Admin
      if (path.startsWith('/ngo')) {
        final isNgoAuthorized = role == UserRole.ngoLead || role == UserRole.admin;
        if (!isNgoAuthorized) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AccessDeniedScreen(
              attemptedPath: path,
              requiredRoleDescription: 'Verified NGO Administrator (DARPAN Registered)',
            ),
          );
        }
      }

      // Field Responder / Rescue modules require Rescue Team, Incident Commander or Admin
      if (path.startsWith('/responder')) {
        final isResponderAuthorized = role == UserRole.rescueTeam ||
            role == UserRole.incidentCommander ||
            role == UserRole.admin;
        if (!isResponderAuthorized) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AccessDeniedScreen(
              attemptedPath: path,
              requiredRoleDescription: 'NDRF / SDRF Field Rescue Team',
            ),
          );
        }
      }

      // Medical modules require Medical Doctor, Incident Commander or Admin
      if (path.startsWith('/medical')) {
        final isMedicalAuthorized = role == UserRole.doctor ||
            role == UserRole.incidentCommander ||
            role == UserRole.admin;
        if (!isMedicalAuthorized) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AccessDeniedScreen(
              attemptedPath: path,
              requiredRoleDescription: 'Licensed Medical Doctor / Trauma Specialist',
            ),
          );
        }
      }
    }

    // Parameterized Route Matching: /citizen/reports/:id or /government/incidents/:id
    if (path.startsWith('/citizen/reports/') && path != AppRoutes.citizenNewReport) {
      final id = path.replaceFirst('/citizen/reports/', '');
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CitizenReportDetailScreen(incidentId: id),
      );
    }

    if (path.startsWith('/government/incidents/')) {
      final id = path.replaceFirst('/government/incidents/', '');
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CitizenReportDetailScreen(incidentId: id),
      );
    }

    Widget page;
    switch (path) {
      // Public
      case AppRoutes.bootstrap:
        page = const AppBootstrapGate();
        break;
      case AppRoutes.home:
        page = const CitizenDashboardScreen();
        break;
      case AppRoutes.login:
        page = const AuthScreen(isRegisterMode: false);
        break;
      case AppRoutes.register:
      case AppRoutes.forgotPassword:
        page = const AuthScreen(isRegisterMode: true);
        break;
      case AppRoutes.disasterMap:
      case AppRoutes.citizenMap:
      case AppRoutes.responderMap:
      case AppRoutes.volunteerMap:
        page = DisasterMapScreen(routePath: path);
        break;
      case AppRoutes.transparency:
        page = const TransparencyOverviewScreen();
        break;
      case AppRoutes.transparencyOrgs:
        page = const TransparencyOrganizationsScreen();
        break;
      case AppRoutes.transparencyFunds:
        page = const TransparencyFundsScreen();
        break;
      case AppRoutes.transparencyAreas:
        page = const TransparencyAreasScreen();
        break;
      case AppRoutes.preparedness:
        page = const PreparednessScreen();
        break;

      // Citizen
      case AppRoutes.citizenDashboard:
        page = const CitizenDashboardScreen();
        break;
      case AppRoutes.citizenHelp:
        page = const CitizenHelpScreen();
        break;
      case AppRoutes.citizenHelpRequest:
        page = const CitizenHelpRequestScreen();
        break;
      case AppRoutes.citizenMissingPerson:
        page = const CitizenMissingPersonScreen();
        break;
      case AppRoutes.citizenSos:
        page = const CitizenSosScreen();
        break;
      case AppRoutes.citizenReports:
      case AppRoutes.citizenAssistance:
        page = const CitizenReportsScreen();
        break;
      case AppRoutes.citizenNewReport:
        page = const CitizenNewReportScreen();
        break;
      case AppRoutes.citizenAlerts:
        page = const CitizenAlertsScreen();
        break;
      case AppRoutes.citizenNotifications:
        page = const NotificationsScreen();
        break;
      case AppRoutes.citizenShelters:
        page = const CitizenSheltersScreen();
        break;
      case AppRoutes.profile:
      case AppRoutes.citizenProfile:
      case AppRoutes.citizenEmergencyContacts:
        page = const UserProfileScreen();
        break;
      case AppRoutes.citizenDonate:
        page = const CitizenCampaignsScreen();
        break;
      case AppRoutes.citizenDonations:
        page = const CitizenDonationsScreen();
        break;

      // NGO
      case AppRoutes.ngoDashboard:
      case AppRoutes.ngoOperations:
      case AppRoutes.ngoVolunteers:
      case AppRoutes.ngoVerification:
      case AppRoutes.ngoReports:
        page = const NgoDashboardScreen();
        break;
      case AppRoutes.ngoCampaigns:
      case AppRoutes.ngoDonations:
      case AppRoutes.ngoFinances:
      case AppRoutes.ngoExpenses:
      case AppRoutes.ngoResources:
      case AppRoutes.ngoBeneficiaries:
      case AppRoutes.ngoCoverageMap:
        page = const NgoManagementScreen();
        break;

      // Volunteer
      case AppRoutes.volunteerDashboard:
      case AppRoutes.volunteerHistory:
      case AppRoutes.volunteerAvailability:
      case AppRoutes.volunteerTraining:
      case AppRoutes.volunteerDonations:
        page = const VolunteerDashboardScreen();
        break;
      case AppRoutes.volunteerProfile:
        page = const UserProfileScreen();
        break;
      case AppRoutes.volunteerOpportunities:
      case AppRoutes.volunteerTasks:
        page = const VolunteerPortalScreen();
        break;

      // Government
      case AppRoutes.governmentDashboard:
      case AppRoutes.governmentCommandCentre:
      case AppRoutes.governmentDispatch:
      case AppRoutes.governmentTeams:
      case AppRoutes.governmentAnnouncements:
        page = const GovernmentCommandCentreScreen();
        break;
      case AppRoutes.governmentIncidents:
      case AppRoutes.governmentVerification:
      case AppRoutes.governmentReliefPrograms:
      case AppRoutes.governmentHospitals:
      case AppRoutes.governmentShelters:
      case AppRoutes.governmentResources:
      case AppRoutes.governmentAnalytics:
      case AppRoutes.governmentAudit:
        page = const GovernmentOperationsScreen();
        break;
      case AppRoutes.governmentFinancialTransparency:
        page = const GovernmentFinancialScreen();
        break;
      case AppRoutes.governmentAreaCoverage:
        page = const TransparencyAreasScreen();
        break;

      // Responder & Medical
      case AppRoutes.responderDashboard:
      case AppRoutes.responderAssignments:
        page = const ResponderDashboardScreen();
        break;
      case AppRoutes.medicalDashboard:
      case AppRoutes.medicalRequests:
      case AppRoutes.medicalHospitals:
      case AppRoutes.medicalResources:
        page = const MedicalDashboardScreen();
        break;

      // AI Intelligence
      case AppRoutes.intelligenceDashboard:
        page = const IntelligenceDashboardScreen();
        break;
      case AppRoutes.intelligenceRiskForecast:
      case AppRoutes.intelligenceImpactAnalysis:
        page = const RiskForecastScreen();
        break;
      case AppRoutes.intelligenceNeedsForecast:
        page = const NeedsForecastScreen();
        break;
      case AppRoutes.intelligenceResourceOptimization:
        page = const ResourceOptimizationScreen();
        break;
      case AppRoutes.intelligenceAnomalies:
        page = const AnomaliesScreen();
        break;
      case AppRoutes.intelligenceSimulation:
        page = const ScenarioSimulationScreen();
        break;
      case AppRoutes.intelligenceModelPerformance:
        page = const ModelPerformanceScreen();
        break;

      default:
        page = const HomePortalScreen();
        break;
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }
}

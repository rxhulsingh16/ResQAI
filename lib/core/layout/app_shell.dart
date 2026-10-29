import '../../shared/widgets/app_widgets.dart';
import '../../data/services/notification_client_service.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../data/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';
import '../utils/i18n.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../router/app_router.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../shared/models/user_model.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;
  final String? title;
  final List<String>? breadcrumbs;
  final Widget? floatingActionButton;
  final bool hideMobileAppBar;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    this.title,
    this.breadcrumbs,
    this.floatingActionButton,
    this.hideMobileAppBar = false,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 768 && width < 1024;
    final isMobile = width < 768;

    final navItems = _getNavItemsForRole(activeRole);
    final isProfileScreen = widget.currentRoute == AppRoutes.citizenProfile ||
        widget.currentRoute == AppRoutes.volunteerProfile ||
        widget.currentRoute == AppRoutes.profile ||
        widget.currentRoute == '/profile';

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop ? null : _buildDrawer(context, navItems, activeRole, currentUser),
      appBar: (isMobile && widget.hideMobileAppBar)
          ? null
          : _buildAppBar(context, isDesktop, isTablet, isMobile, currentUser, activeRole),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop)
            SizedBox(
              width: 260,
              child: _buildDesktopSidebar(context, navItems, activeRole, currentUser),
            ),
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkBg : AppColors.lightBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPersistent112Banner(),
                  if (!isMobile && widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty)
                    _buildBreadcrumbBar(isDark),
                  Expanded(
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: (isMobile && !isProfileScreen) ? _buildMobileBottomBar(context, activeRole, currentUser) : null,
      floatingActionButton: widget.floatingActionButton,
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    dynamic currentUser,
    UserRole activeRole,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final canPop = Navigator.canPop(context);

    final isProfileScreen = widget.currentRoute == AppRoutes.citizenProfile ||
        widget.currentRoute == AppRoutes.volunteerProfile ||
        widget.currentRoute == AppRoutes.profile ||
        widget.currentRoute == '/profile';

    return AppBar(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: isDesktop
          ? null
          : (isProfileScreen
              ? IconButton(
                  icon: const Icon(Icons.menu, size: 22),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Navigation Menu',
                )
              : (canPop
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    )
                  : IconButton(
                      icon: const Icon(Icons.menu, size: 22),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: 'Navigation Menu',
                    ))),
      titleSpacing: isDesktop ? 20 : ((canPop && !isProfileScreen) ? 0 : 8),
      title: isProfileScreen
          ? Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : AppColors.deepNavy,
              ),
            )
          : ((isMobile && canPop)
              ? Text(
                  widget.title ?? AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                  ),
                )
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                InkWell(
                  onTap: () {
                    switch (activeRole) {
                      case UserRole.citizen:
                        Navigator.pushNamed(context, AppRoutes.citizenDashboard);
                        break;
                      case UserRole.volunteer:
                        Navigator.pushNamed(context, AppRoutes.volunteerDashboard);
                        break;
                      case UserRole.ngoLead:
                        Navigator.pushNamed(context, AppRoutes.ngoDashboard);
                        break;
                      case UserRole.govtOfficial:
                        Navigator.pushNamed(context, AppRoutes.governmentCommandCentre);
                        break;
                      case UserRole.rescueTeam:
                        Navigator.pushNamed(context, AppRoutes.responderDashboard);
                        break;
                      case UserRole.doctor:
                        Navigator.pushNamed(context, AppRoutes.medicalDashboard);
                        break;
                      default:
                        Navigator.pushNamed(context, AppRoutes.home);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: 0.3,
                              color: isDark ? Colors.white : AppColors.deepNavy,
                            ),
                          ),
                          if (!isMobile)
                            Text(
                              'DISASTER MANAGEMENT & RELIEF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.title != null && !isMobile) ...[
                  const SizedBox(width: 14),
                  Container(height: 18, width: 1, color: borderColor),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      actions: [
        // Live IMD / NDRF status indicator
        if (!isMobile)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, color: AppColors.successGreen, size: 10),
                SizedBox(width: 6),
                Text(
                  'ONLINE • YAMUNA BASIN ALERT',
                  style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        // Quick SOS Button (Desktop only; on mobile SOS is in BottomBar or floating map)
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.emergency, size: 16),
              label: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
              onPressed: () => AppRouter.navigateToSos(context),
            ),
          ),

        
        // Check for Updates action
        IconButton(
          icon: const Icon(Icons.system_update_alt, size: 19),
          tooltip: 'Check for Updates',
          onPressed: () => AppUpdateService.showUpdateCheckDialog(context, ref: ref),
        ),
        // Live Notification Bell with Dynamic Unread Counter
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadNotificationCountProvider);
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 22),
                  tooltip: 'Emergency Bulletins & Notifications (' + unread.toString() + ')',
                  onPressed: () => NotificationsScreen.showNotificationCenter(context),
                ),
                Positioned(
                  right: 6,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: unread > 0 ? AppColors.emergencyRed : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unread.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // Language Selector
        Consumer(
          builder: (context, ref, _) {
            final lang = ref.watch(languageProvider);
            return TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                ref.read(languageProvider.notifier).toggleLanguage();
              },
              child: Text(
                lang == 'en' ? 'हि' : 'EN',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            );
          },
        ),

        // User Login / Profile
        if (currentUser == null)
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 6 : 12, left: 4),
            child: isMobile
                ? IconButton(
                    icon: const Icon(Icons.login, size: 20),
                    tooltip: 'Sign In',
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.login, size: 16),
                        label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
          )
        else
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 12, left: 4),
            child: PopupMenuButton<String>(
              tooltip: 'Account Options',
              child: isMobile
                  ? CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryBlue,
                      child: Text(
                        currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  : Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primaryBlue,
                        child: Text(
                          currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      label: Text(
                        currentUser.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
              itemBuilder: (context) => [
                
                PopupMenuItem(
                  value: 'updates',
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.system_update, size: 18, color: AppColors.primaryBlue),
                    title: Text('Check for Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => AppUpdateService.showUpdateCheckDialog(context, ref: ref),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.person, size: 18, color: AppColors.primaryBlue),
                    title: Text('My Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.citizenProfile),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.settings, size: 18, color: Colors.grey),
                    title: Text('Account Settings', style: TextStyle(fontSize: 13)),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserProfileScreen(initialTabIndex: 1)),
                    );
                  },
                ),
                PopupMenuItem(
                  value: 'notifications',
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.notifications_active, size: 18, color: AppColors.warningOrange),
                    title: Text('Notification Preferences', style: TextStyle(fontSize: 13)),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserProfileScreen(initialTabIndex: 2)),
                    );
                  },
                ),
                PopupMenuItem(
                  value: 'help',
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.help_outline, size: 18, color: AppColors.infoBlue),
                    title: Text('Help & Helplines', style: TextStyle(fontSize: 13)),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserProfileScreen(initialTabIndex: 4)),
                    );
                  },
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.logout, size: 18, color: AppColors.emergencyRed),
                    title: Text('Sign Out', style: TextStyle(fontSize: 13, color: AppColors.emergencyRed, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
                    ref.read(activeRoleProvider.notifier).state = UserRole.citizen;
                    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.primaryBlue,
                        content: Text('✓ Signed out successfully. Session ended.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: borderColor, height: 1),
      ),
    );
  }

  Widget _buildPersistent112Banner() {
    return Container(
      width: double.infinity,
      color: AppColors.emergencyRed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emergency, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'If life is in immediate danger, call 112.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.home, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
          const SizedBox(width: 8),
          for (int i = 0; i < widget.breadcrumbs!.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
              ),
            Text(
              widget.breadcrumbs![i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == widget.breadcrumbs!.length - 1 ? FontWeight.w700 : FontWeight.w500,
                color: i == widget.breadcrumbs!.length - 1
                    ? (isDark ? Colors.white : AppColors.primaryText)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    List<_NavItem> navItems,
    UserRole activeRole,
    dynamic currentUser,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Navigation Links
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: navItems.length,
              separatorBuilder: (context, index) {
                if (index < navItems.length - 1 && navItems[index].category != navItems[index + 1].category) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: borderColor, height: 1),
                  );
                }
                return const SizedBox(height: 3);
              },
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = widget.currentRoute == item.route;

                return InkWell(
                  onTap: () => Navigator.pushNamed(context, item.route),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlue.withOpacity(isDark ? 0.2 : 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppColors.primaryBlue.withOpacity(0.4))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.primaryBlue
                              : (isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : AppColors.primaryBlue)
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.primaryText),
                            ),
                          ),
                        ),
                        if (item.badgeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item.badgeCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Quick Links (Transparency & Preparedness)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                _buildSidebarTile(
                  context,
                  title: 'Public Transparency',
                  icon: Icons.account_balance,
                  route: AppRoutes.transparency,
                  isSelected: widget.currentRoute.startsWith('/transparency'),
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildSidebarTile(
                  context,
                  title: 'Disaster Map GIS',
                  icon: Icons.map,
                  route: AppRoutes.disasterMap,
                  isSelected: widget.currentRoute == AppRoutes.disasterMap,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _buildSidebarTile(
                  context,
                  title: 'AI Intelligence Hub',
                  icon: Icons.psychology,
                  route: AppRoutes.intelligenceDashboard,
                  isSelected: widget.currentRoute.startsWith('/intelligence'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.darkTextSecondary : AppColors.mutedText)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.darkTextPrimary : AppColors.primaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    List<_NavItem> navItems,
    UserRole activeRole,
    dynamic currentUser,
  ) {
    return SideDrawer(currentRoute: widget.currentRoute);
  }

  Widget _buildMobileBottomBar(BuildContext context, UserRole role, UserModel? currentUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final primaryActions = _getMobilePrimaryActions(role, currentUser);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: primaryActions.map((action) {
              final isSelected = widget.currentRoute == action.route;
              return InkWell(
                onTap: () => Navigator.pushNamed(context, action.route),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: isSelected ? 12 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? AppColors.primaryGreen.withOpacity(0.2)
                            : AppColors.lightGreen)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action.icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primaryGreen
                            : (isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primaryGreen
                              : (isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<_NavItem> _getNavItemsForRole(UserRole role) {
    switch (role) {
      case UserRole.citizen:
        return [
          _NavItem('Dashboard', Icons.dashboard_outlined, AppRoutes.citizenDashboard, 'Home'),
          _NavItem('Disaster Help Hub', Icons.support_agent_outlined, AppRoutes.citizenHelp, 'Emergency'),
          _NavItem('Emergency SOS', Icons.emergency, AppRoutes.citizenSos, 'Emergency'),
          _NavItem('Request Humanitarian Aid', Icons.volunteer_activism_outlined, AppRoutes.citizenHelpRequest, 'Emergency'),
          _NavItem('Report Missing Person', Icons.person_search_outlined, AppRoutes.citizenMissingPerson, 'Emergency'),
          _NavItem('Live Disaster Map', Icons.map_outlined, AppRoutes.citizenMap, 'Navigation'),
          _NavItem('Emergency Alerts', Icons.campaign_outlined, AppRoutes.citizenAlerts, 'Navigation', badgeCount: 2),
          _NavItem('My Requests & Claims', Icons.assignment_outlined, AppRoutes.citizenReports, 'Reports'),
          _NavItem('File Damage Report', Icons.add_circle_outline, AppRoutes.citizenNewReport, 'Reports'),
          _NavItem('Nearby Shelters', Icons.night_shelter_outlined, AppRoutes.citizenShelters, 'Assistance'),
          _NavItem('Donate Relief', Icons.favorite_outline, AppRoutes.citizenDonate, 'Giving'),
          _NavItem('Donation History', Icons.receipt_long_outlined, AppRoutes.citizenDonations, 'Giving'),
          _NavItem('Emergency Contacts', Icons.contact_phone_outlined, AppRoutes.citizenEmergencyContacts, 'Profile'),
          _NavItem('Citizen Profile', Icons.person_outline, AppRoutes.citizenProfile, 'Profile'),
        ];
      case UserRole.ngoLead:
        return [
          _NavItem('NGO Dashboard', Icons.dashboard_outlined, AppRoutes.ngoDashboard, 'Operations'),
          _NavItem('Relief Campaigns', Icons.volunteer_activism_outlined, AppRoutes.ngoCampaigns, 'Operations'),
          _NavItem('Finances & Ledger', Icons.receipt_long_outlined, AppRoutes.ngoFinances, 'Financials'),
          _NavItem('Expense Invoices', Icons.attach_money, AppRoutes.ngoExpenses, 'Financials'),
          _NavItem('Warehouse Supplies', Icons.inventory_2_outlined, AppRoutes.ngoResources, 'Logistics'),
          _NavItem('Coverage Area Map', Icons.explore_outlined, AppRoutes.ngoCoverageMap, 'Logistics'),
          _NavItem('Field Volunteers', Icons.group_outlined, AppRoutes.ngoVolunteers, 'Logistics'),
        ];
      case UserRole.volunteer:
        return [
          _NavItem('Volunteer Home', Icons.dashboard_outlined, AppRoutes.volunteerDashboard, 'Tasks'),
          _NavItem('Task Opportunities', Icons.search_outlined, AppRoutes.volunteerOpportunities, 'Tasks'),
          _NavItem('Active Assignments', Icons.checklist_outlined, AppRoutes.volunteerTasks, 'Tasks'),
          _NavItem('Field Map Navigator', Icons.navigation_outlined, AppRoutes.volunteerMap, 'Field'),
          _NavItem('Service History', Icons.history_edu_outlined, AppRoutes.volunteerHistory, 'Profile'),
          _NavItem('Volunteer Profile', Icons.badge_outlined, AppRoutes.volunteerProfile, 'Profile'),
        ];
      case UserRole.govtOfficial:
      case UserRole.incidentCommander:
      case UserRole.admin:
        return [
          _NavItem('Overview Dashboard', Icons.dashboard_outlined, AppRoutes.governmentDashboard, 'Command'),
          _NavItem('Tactical Command Centre', Icons.radar, AppRoutes.governmentCommandCentre, 'Command'),
          _NavItem('Incident Review Ledger', Icons.gavel_outlined, AppRoutes.governmentIncidents, 'Incidents'),
          _NavItem('Relief Sanction Queue', Icons.verified_user_outlined, AppRoutes.governmentVerification, 'Incidents'),
          _NavItem('SDRF Financial Ledger', Icons.account_balance_outlined, AppRoutes.governmentFinancialTransparency, 'Finance'),
          _NavItem('District Coverage Matrix', Icons.analytics_outlined, AppRoutes.governmentAreaCoverage, 'Analytics'),
        ];
      case UserRole.rescueTeam:
      case UserRole.fieldResponder:
        return [
          _NavItem('Rescue Dashboard', Icons.dashboard_outlined, AppRoutes.responderDashboard, 'Missions'),
          _NavItem('Incident Queue', Icons.format_list_bulleted, AppRoutes.responderAssignments, 'Missions'),
          _NavItem('Tactical GIS Map', Icons.map_outlined, AppRoutes.responderMap, 'Navigation'),
        ];
      case UserRole.doctor:
        return [
          _NavItem('Medical Dashboard', Icons.dashboard_outlined, AppRoutes.medicalDashboard, 'Triage'),
          _NavItem('Casualty Triage Queue', Icons.medical_services_outlined, AppRoutes.medicalRequests, 'Triage'),
          _NavItem('Hospital Bed Registry', Icons.local_hospital_outlined, AppRoutes.medicalHospitals, 'Resources'),
        ];
      default:
        return [
          _NavItem('Citizen Portal', Icons.person_outline, AppRoutes.citizenDashboard, 'Home'),
          _NavItem('Public Map', Icons.map_outlined, AppRoutes.disasterMap, 'Home'),
          _NavItem('Transparency', Icons.account_balance_outlined, AppRoutes.transparency, 'Home'),
        ];
    }
  }

  List<_NavItem> _getMobilePrimaryActions(UserRole role, UserModel? currentUser) {
    if (currentUser == null) {
      return const [
        _NavItem('Home', Icons.home, AppRoutes.home, ''),
        _NavItem('Alerts', Icons.campaign_outlined, AppRoutes.citizenAlerts, ''),
        _NavItem('Map', Icons.map_outlined, AppRoutes.disasterMap, ''),
        _NavItem('Sign In', Icons.login, AppRoutes.login, ''),
      ];
    }

    switch (role) {
      case UserRole.citizen:
        return const [
          _NavItem('Home', Icons.home, AppRoutes.citizenDashboard, ''),
          _NavItem('Help Hub', Icons.support_agent_outlined, AppRoutes.citizenHelp, ''),
          _NavItem('SOS', Icons.emergency, AppRoutes.citizenSos, ''),
          _NavItem('Requests', Icons.assignment_outlined, AppRoutes.citizenReports, ''),
          _NavItem('Profile', Icons.person_outline, AppRoutes.citizenProfile, ''),
        ];
      case UserRole.volunteer:
        return const [
          _NavItem('Home', Icons.home, AppRoutes.volunteerDashboard, ''),
          _NavItem('Tasks', Icons.checklist, AppRoutes.volunteerTasks, ''),
          _NavItem('Map', Icons.navigation, AppRoutes.volunteerMap, ''),
          _NavItem('Profile', Icons.person, AppRoutes.volunteerProfile, ''),
        ];
      case UserRole.ngoLead:
        return const [
          _NavItem('Home', Icons.home, AppRoutes.ngoDashboard, ''),
          _NavItem('Campaigns', Icons.volunteer_activism, AppRoutes.ngoCampaigns, ''),
          _NavItem('Finances', Icons.receipt_long, AppRoutes.ngoFinances, ''),
          _NavItem('Map', Icons.map, AppRoutes.ngoCoverageMap, ''),
          _NavItem('Profile', Icons.person_outline, AppRoutes.citizenProfile, ''),
        ];
      case UserRole.govtOfficial:
      case UserRole.incidentCommander:
      case UserRole.admin:
        return const [
          _NavItem('Command', Icons.radar, AppRoutes.governmentCommandCentre, ''),
          _NavItem('Incidents', Icons.assignment_late, AppRoutes.governmentIncidents, ''),
          _NavItem('SDRF', Icons.account_balance, AppRoutes.governmentFinancialTransparency, ''),
          _NavItem('AI', Icons.psychology, AppRoutes.intelligenceDashboard, ''),
          _NavItem('Profile', Icons.person_outline, AppRoutes.citizenProfile, ''),
        ];
      case UserRole.rescueTeam:
      case UserRole.fieldResponder:
        return const [
          _NavItem('Command', Icons.radar, AppRoutes.responderDashboard, ''),
          _NavItem('Incidents', Icons.emergency, AppRoutes.citizenSos, ''),
          _NavItem('Map', Icons.map, AppRoutes.disasterMap, ''),
          _NavItem('Profile', Icons.person_outline, AppRoutes.citizenProfile, ''),
        ];
      case UserRole.doctor:
        return const [
          _NavItem('Medical', Icons.dashboard_outlined, AppRoutes.medicalDashboard, ''),
          _NavItem('Triage', Icons.medical_services_outlined, AppRoutes.medicalRequests, ''),
          _NavItem('Hospitals', Icons.local_hospital_outlined, AppRoutes.medicalHospitals, ''),
          _NavItem('Profile', Icons.person_outline, AppRoutes.citizenProfile, ''),
        ];
      default:
        return const [
          _NavItem('Home', Icons.home, AppRoutes.citizenDashboard, ''),
          _NavItem('Help Hub', Icons.support_agent_outlined, AppRoutes.citizenHelp, ''),
          _NavItem('SOS', Icons.emergency, AppRoutes.citizenSos, ''),
          _NavItem('Requests', Icons.assignment_outlined, AppRoutes.citizenReports, ''),
          _NavItem('Profile', Icons.person_outline, AppRoutes.citizenProfile, ''),
        ];
    }
  }

  void _navigateToRoleDefault(BuildContext context, UserRole role) {
    switch (role) {
      case UserRole.citizen:
        Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard);
        break;
      case UserRole.volunteer:
        Navigator.pushReplacementNamed(context, AppRoutes.volunteerDashboard);
        break;
      case UserRole.ngoLead:
        Navigator.pushReplacementNamed(context, AppRoutes.ngoDashboard);
        break;
      case UserRole.govtOfficial:
      case UserRole.incidentCommander:
      case UserRole.admin:
        Navigator.pushReplacementNamed(context, AppRoutes.governmentCommandCentre);
        break;
      case UserRole.rescueTeam:
      case UserRole.fieldResponder:
        Navigator.pushReplacementNamed(context, AppRoutes.responderDashboard);
        break;
      case UserRole.doctor:
        Navigator.pushReplacementNamed(context, AppRoutes.medicalDashboard);
        break;
      default:
        Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard);
        break;
    }
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String category;
  final int badgeCount;

  const _NavItem(this.label, this.icon, this.route, this.category, {this.badgeCount = 0});
}

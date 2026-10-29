import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// 1. AppCard: Standardized Theme Surface Card (No Hardcoded Black)
// ============================================================================
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius = 16,
    this.elevation = 0,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard);
    final border = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? cardColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1.2),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation * 1.5),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: container,
        ),
      );
    }

    return container;
  }
}

// ============================================================================
// 2. StatCard: Equal-Sized, Non-Overflowing Statistic Box
// ============================================================================
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? AppColors.primaryGreen;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepNavy,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. AppButton: Minimum 48dp Touch-Target Standardized Button
// ============================================================================
enum AppButtonVariant { primary, danger, outlined, text }

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget childContent;
    if (isLoading) {
      childContent = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
    } else if (icon != null) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      );
    } else {
      childContent = Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      );
    }

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            minimumSize: Size(isFullWidth ? double.infinity : 88, height),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            elevation: 1,
          ),
          onPressed: isLoading ? null : onPressed,
          child: childContent,
        );
        break;

      case AppButtonVariant.danger:
        button = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            minimumSize: Size(isFullWidth ? double.infinity : 88, height),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            elevation: 1,
          ),
          onPressed: isLoading ? null : onPressed,
          child: childContent,
        );
        break;

      case AppButtonVariant.outlined:
        button = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppColors.mintGreen : AppColors.primaryGreen,
            side: BorderSide(color: isDark ? AppColors.mintGreen : AppColors.primaryGreen, width: 1.5),
            minimumSize: Size(isFullWidth ? double.infinity : 88, height),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          onPressed: isLoading ? null : onPressed,
          child: childContent,
        );
        break;

      case AppButtonVariant.text:
        button = TextButton(
          style: TextButton.styleFrom(
            foregroundColor: isDark ? AppColors.mintGreen : AppColors.primaryGreen,
            minimumSize: Size(isFullWidth ? double.infinity : 64, height),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: isLoading ? null : onPressed,
          child: childContent,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

// ============================================================================
// 4. StatusChip: Semantic Status Tag (Red, Green, Amber, Blue)
// ============================================================================
enum StatusChipType { danger, warning, success, info, neutral }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusChipType type;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.type = StatusChipType.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case StatusChipType.danger:
        bg = AppColors.red50;
        fg = AppColors.red700;
        border = AppColors.red200;
        break;
      case StatusChipType.warning:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        break;
      case StatusChipType.success:
        bg = AppColors.emerald50;
        fg = AppColors.emerald800;
        border = AppColors.emerald200;
        break;
      case StatusChipType.info:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        border = const Color(0xFFBFDBFE);
        break;
      case StatusChipType.neutral:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        border = Colors.grey.shade300;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. SectionHeader: Title & Action
// ============================================================================
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepNavy,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. EmptyState: Clean Guidance
// ============================================================================
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. ErrorState: Error Banner with Retry
// ============================================================================
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.primaryRed),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              AppButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: onRetry,
                variant: AppButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. LoadingSkeleton: Animated Pulsing Placeholder
// ============================================================================
class LoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ============================================================================
// 9. SideDrawer: Unified Role-Scoped Navigation Drawer
// ============================================================================
class SideDrawer extends ConsumerWidget {
  final String currentRoute;

  const SideDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final role = user?.role ?? activeRole;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightGreen,
                border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryGreen,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Guest User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role.title,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _buildRoleDrawerItems(context, role, currentRoute, isDark),
              ),
            ),

            const Divider(height: 1),

            // Helplines & Logout
            ListTile(
              leading: const Icon(Icons.phone_in_talk, size: 20, color: AppColors.primaryGreen),
              title: const Text('Emergency Helplines (112 / 1078)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.citizenHelp);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, size: 20, color: AppColors.primaryRed),
              title: const Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
              onTap: () {
                ref.read(authProvider.notifier).logout();
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoleDrawerItems(BuildContext context, UserRole role, String currentRoute, bool isDark) {
    final List<Map<String, dynamic>> items = [];

    // Role-specific destinations
    switch (role) {
      case UserRole.citizen:
        items.addAll([
          {'title': 'Dashboard', 'icon': Icons.home, 'route': AppRoutes.citizenDashboard},
          {'title': 'Disaster Help Hub', 'icon': Icons.support_agent, 'route': AppRoutes.citizenHelp},
          {'title': 'Emergency SOS', 'icon': Icons.emergency, 'route': AppRoutes.citizenSos},
          {'title': 'Tactical Disaster Map', 'icon': Icons.map, 'route': AppRoutes.disasterMap},
          {'title': 'My Requests & Reports', 'icon': Icons.assignment, 'route': AppRoutes.citizenReports},
          {'title': 'Profile', 'icon': Icons.person, 'route': AppRoutes.profile},
        ]);
        break;

      case UserRole.ngoLead:
        items.addAll([
          {'title': 'Operations Command', 'icon': Icons.business, 'route': AppRoutes.ngoDashboard},
          {'title': 'Relief Campaigns', 'icon': Icons.volunteer_activism, 'route': AppRoutes.ngoCampaigns},
          {'title': 'Financial Ledger', 'icon': Icons.receipt_long, 'route': AppRoutes.ngoFinances},
          {'title': 'Warehouse Supplies', 'icon': Icons.inventory, 'route': AppRoutes.ngoResources},
          {'title': 'Tactical Map', 'icon': Icons.map, 'route': AppRoutes.disasterMap},
          {'title': 'Profile', 'icon': Icons.person, 'route': AppRoutes.profile},
        ]);
        break;

      case UserRole.volunteer:
        items.addAll([
          {'title': 'Volunteer Portal', 'icon': Icons.handshake, 'route': AppRoutes.volunteerDashboard},
          {'title': 'Field Tasks Queue', 'icon': Icons.task, 'route': AppRoutes.volunteerTasks},
          {'title': 'Tactical Map', 'icon': Icons.map, 'route': AppRoutes.disasterMap},
          {'title': 'Profile', 'icon': Icons.person, 'route': AppRoutes.profile},
        ]);
        break;

      case UserRole.rescueTeam:
      case UserRole.fieldResponder:
        items.addAll([
          {'title': 'Responder Command', 'icon': Icons.local_shipping, 'route': AppRoutes.responderDashboard},
          {'title': 'Assigned Missions', 'icon': Icons.flag, 'route': AppRoutes.responderAssignments},
          {'title': 'Tactical Map', 'icon': Icons.map, 'route': AppRoutes.disasterMap},
          {'title': 'Profile', 'icon': Icons.person, 'route': AppRoutes.profile},
        ]);
        break;

      case UserRole.doctor:
        items.addAll([
          {'title': 'Medical Triage', 'icon': Icons.medical_services, 'route': AppRoutes.medicalDashboard},
          {'title': 'Casualty Referrals', 'icon': Icons.local_hospital, 'route': AppRoutes.medicalRequests},
          {'title': 'Profile', 'icon': Icons.person, 'route': AppRoutes.profile},
        ]);
        break;

      case UserRole.admin:
      case UserRole.govtOfficial:
      case UserRole.incidentCommander:
        items.addAll([
          {'title': 'Command Center', 'icon': Icons.account_balance, 'route': AppRoutes.governmentCommandCentre},
          {'title': 'Emergency Operations', 'icon': Icons.shield, 'route': AppRoutes.governmentOperations},
          {'title': 'Financial Transparency', 'icon': Icons.payments, 'route': AppRoutes.governmentFinancialTransparency},
          {'title': 'Tactical Map', 'icon': Icons.map, 'route': AppRoutes.disasterMap},
          {'title': 'Public Transparency Portal', 'icon': Icons.public, 'route': AppRoutes.publicTransparency},
          {'title': 'Profile', 'icon': Icons.person, 'route': AppRoutes.profile},
        ]);
        break;

      default:
        items.addAll([
          {'title': 'Home', 'icon': Icons.home, 'route': AppRoutes.home},
          {'title': 'Disaster Map', 'icon': Icons.map, 'route': AppRoutes.disasterMap},
          {'title': 'Sign In', 'icon': Icons.login, 'route': AppRoutes.auth},
        ]);
    }

    return items.map((item) {
      final isSelected = currentRoute == item['route'];
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(
            item['icon'] as IconData,
            size: 20,
            color: isSelected ? AppColors.primaryGreen : (isDark ? Colors.white70 : AppColors.deepNavy),
          ),
          title: Text(
            item['title'] as String,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.primaryGreen : (isDark ? Colors.white : AppColors.deepNavy),
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            if (!isSelected) {
              Navigator.pushReplacementNamed(context, item['route'] as String);
            }
          },
        ),
      );
    }).toList();
  }
}

// ============================================================================
// 10. AppScaffold: Standardized Shell with Consistent Navigation
// ============================================================================
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final String currentRoute;
  final bool showBackButton;
  final bool showCloseButton;
  final bool showDrawerButton;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.currentRoute,
    this.showBackButton = true,
    this.showCloseButton = false,
    this.showDrawerButton = false,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget? leading;
    if (showCloseButton) {
      leading = IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Close',
        onPressed: () => Navigator.pop(context),
      );
    } else if (showDrawerButton) {
      leading = Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      );
    } else if (showBackButton && canPop) {
      leading = IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      drawer: showDrawerButton ? SideDrawer(currentRoute: currentRoute) : null,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.deepNavy,
          ),
        ),
        leading: leading,
        actions: actions,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

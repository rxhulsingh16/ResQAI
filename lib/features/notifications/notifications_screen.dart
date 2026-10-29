import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/notification_client_service.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static void showNotificationCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationsSheetModal(),
    );
  }

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _receivedFilter = 'ALL'; // 'ALL', 'UNREAD', 'CRITICAL'
  String _sentFilter = 'ALL';     // 'ALL', 'ACTIVE', 'DELIVERED'
  bool _showOlderReceived = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showNewBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String severity = 'HIGH';
    String audience = 'ALL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.campaign, color: AppColors.primaryRed, size: 24),
                SizedBox(width: 10),
                Text('Broadcast Alert', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: audience,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Citizens & Responders')),
                      DropdownMenuItem(value: 'CITIZEN', child: Text('Citizens in District')),
                      DropdownMenuItem(value: 'VOLUNTEER', child: Text('Field Volunteers Only')),
                      DropdownMenuItem(value: 'NGO_LEAD', child: Text('NGO Relief Coordinators')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => audience = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Severity Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildSeverityRadio('CRITICAL', AppColors.emergencyRed, severity, (v) => setDialogState(() => severity = v)),
                      const SizedBox(width: 8),
                      _buildSeverityRadio('HIGH', AppColors.warningOrange, severity, (v) => setDialogState(() => severity = v)),
                      const SizedBox(width: 8),
                      _buildSeverityRadio('INFO', AppColors.primaryGreen, severity, (v) => setDialogState(() => severity = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Alert Headline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Flash Flood Evacuation Notice',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Directives & Location Guidance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Provide specific route or safety actions for citizens...',
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Transmit Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  final body = bodyCtrl.text.trim();
                  if (title.isEmpty || body.isEmpty) return;

                  ref.read(notificationsProvider.notifier).addAlertNotification(
                    title: title,
                    body: body,
                    severity: severity,
                    source: 'Station Command Broadcast',
                    direction: 'SENT',
                    status: 'BROADCAST ACTIVE',
                    type: 'DISASTER_ALERT',
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency broadcast transmitted across all life-safety channels.'),
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeverityRadio(String val, Color color, String current, Function(String) onSelect) {
    final isSelected = current == val;
    return InkWell(
      onTap: () => onSelect(val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade400, width: isSelected ? 1.8 : 1),
        ),
        child: Text(
          val,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey.shade700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allNotifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final receivedList = allNotifications.where((n) => n.direction == 'RECEIVED').toList();
    final sentList = allNotifications.where((n) => n.direction == 'SENT').toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Life-Safety Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(width: 8),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Notifications',
            onPressed: () => ref.read(notificationsProvider.notifier).refreshFromServer(),
          ),
          IconButton(
            icon: const Icon(Icons.add_alert_outlined, size: 20),
            tooltip: 'Transmit Broadcast',
            onPressed: _showNewBroadcastDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : AppColors.deepNavy,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 16),
                  const SizedBox(width: 6),
                  Text('Received (${receivedList.length})'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.outbox, size: 16),
                  const SizedBox(width: 6),
                  Text('Sent (${sentList.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: RECEIVED NOTIFICATIONS
          _buildReceivedTab(context, receivedList, unreadCount, isDark),

          // TAB 2: SENT BROADCASTS & TRANSMISSIONS
          _buildSentTab(context, sentList, isDark),
        ],
      ),
    );
  }

  Widget _buildReceivedTab(BuildContext context, List<AppNotificationItem> items, int unreadCount, bool isDark) {
    final filtered = items.where((n) {
      if (_receivedFilter == 'UNREAD') return !n.isRead;
      if (_receivedFilter == 'CRITICAL') return n.severity == 'CRITICAL';
      return true;
    }).toList();

    final unreadItems = filtered.where((n) => !n.isRead).toList();
    final readItems = filtered.where((n) => n.isRead).toList();

    final displayedList = _showOlderReceived
        ? filtered
        : [...unreadItems, ...readItems.take(4)];

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refreshFromServer(),
      color: AppColors.primaryGreen,
      child: Column(
        children: [
          // Filter Chips & Mark All Read
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
            child: Row(
              children: [
                _buildFilterChip('All (${items.length})', 'ALL', _receivedFilter, (v) => setState(() => _receivedFilter = v), isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Unread ($unreadCount)', 'UNREAD', _receivedFilter, (v) => setState(() => _receivedFilter = v), isDark, isHighlight: unreadCount > 0),
                const SizedBox(width: 8),
                _buildFilterChip('Critical', 'CRITICAL', _receivedFilter, (v) => setState(() => _receivedFilter = v), isDark, isEmergency: true),
                const Spacer(),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      ref.read(notificationsProvider.notifier).markAllAsRead();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All notifications marked as read.')),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Mark all read', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _receivedFilter == 'UNREAD' ? 'You are all caught up!' : 'No notifications in this filter',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      ...displayedList.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildNotificationCard(context, item, isDark),
                          )),
                      if (readItems.length > 4)
                        Center(
                          child: TextButton.icon(
                            icon: Icon(_showOlderReceived ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.primaryGreen),
                            label: Text(
                              _showOlderReceived
                                  ? 'Hide older archived notifications'
                                  : 'Show ${readItems.length - 4} older notifications',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryGreen),
                            ),
                            onPressed: () => setState(() => _showOlderReceived = !_showOlderReceived),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentTab(BuildContext context, List<AppNotificationItem> items, bool isDark) {
    final filtered = items.where((n) {
      if (_sentFilter == 'ACTIVE') return n.status.contains('ACTIVE');
      if (_sentFilter == 'DELIVERED') return n.status == 'DELIVERED';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refreshFromServer(),
      color: AppColors.primaryRed,
      child: Column(
        children: [
          // Filter Chips & New Broadcast Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
            child: Row(
              children: [
                _buildFilterChip('All Sent (${items.length})', 'ALL', _sentFilter, (v) => setState(() => _sentFilter = v), isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Active Broadcasts', 'ACTIVE', _sentFilter, (v) => setState(() => _sentFilter = v), isDark, isHighlight: true),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showNewBroadcastDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Send Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.outbox, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No alerts sent yet from this role',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _showNewBroadcastDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryRed,
                            side: const BorderSide(color: AppColors.primaryRed),
                          ),
                          child: const Text('Create Emergency Broadcast'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildSentCard(context, item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String current, Function(String) onSelect, bool isDark, {bool isHighlight = false, bool isEmergency = false}) {
    final isSelected = current == value;
    Color activeBg = AppColors.primaryGreen;
    if (isEmergency || isHighlight) activeBg = AppColors.primaryRed;

    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeBg : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.deepNavy),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotificationItem item, bool isDark) {
    Color sevColor = AppColors.primaryGreen;
    if (item.severity.toUpperCase() == 'CRITICAL') sevColor = AppColors.emergencyRed;
    if (item.severity.toUpperCase() == 'HIGH' || item.severity.toUpperCase() == 'WARN') sevColor = AppColors.warningOrange;

    final unreadBg = isDark ? AppColors.darkSurface2 : AppColors.lightGreen;
    final readBg = isDark ? AppColors.darkSurface : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(notificationsProvider.notifier).markAsRead(item.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => NotificationDetailScreen(notification: item),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: !item.isRead ? unreadBg : readBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !item.isRead ? sevColor.withOpacity(0.4) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: !item.isRead ? 1.5 : 1,
            ),
            boxShadow: [
              if (!item.isRead)
                BoxShadow(
                  color: sevColor.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: sevColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.severity.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.source,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : AppColors.mutedText,
                    ),
                  ),
                  const Spacer(),
                  if (!item.isRead)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: !item.isRead ? FontWeight.w800 : FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 4),

              // Body
              Text(
                item.body,
                maxLines: !item.isRead ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                  height: 1.35,
                ),
              ),

              // Location tag
              if (item.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      item.location!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentCard(BuildContext context, AppNotificationItem item, bool isDark) {
    final isActive = item.status.contains('ACTIVE');
    final statusColor = isActive ? AppColors.primaryRed : AppColors.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'To: ${item.targetRoles.join(', ')}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(item.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.body,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
              height: 1.35,
            ),
          ),
          if (item.location != null) ...[
            const SizedBox(height: 6),
            Text(
              '📍 Region: ${item.location}',
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class NotificationsSheetModal extends StatelessWidget {
  const NotificationsSheetModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: const NotificationsScreen(),
    );
  }
}

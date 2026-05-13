import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/rental_reservation.dart';
import '../pages/add_appliance_page.dart';
import '../pages/browse_page.dart';
import '../pages/my_reservations_page.dart';
import '../pages/owner_dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    BrowsePage(),
    AddAppliancePage(),
    MyReservationsPage(),
    OwnerDashboardPage(),
  ];

  final List<String> _titles = const [
    'Zoeken',
    'Toestel aanbieden',
    'Mijn reserveringen',
    'Dashboard verhuurder',
  ];

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isFinished(RentalReservation reservation) {
    final today = _dateOnly(DateTime.now());
    final endDate = _dateOnly(reservation.endDate);

    return endDate.isBefore(today);
  }

  bool _needsReturnConfirmation(RentalReservation reservation) {
    return reservation.status == 'accepted' && _isFinished(reservation);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _reservationStreamFor({
    required String field,
    required String uid,
  }) {
    return FirebaseFirestore.instance
        .collection('reservations')
        .where(field, isEqualTo: uid)
        .snapshots();
  }

  List<RentalReservation> _reservationsFromSnapshot(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (!snapshot.hasData) return [];

    return snapshot.data!.docs.map(RentalReservation.fromDoc).toList();
  }

  _NotificationData _buildNotificationData({
    required String uid,
    required List<RentalReservation> ownerReservations,
    required List<RentalReservation> renterReservations,
  }) {
    final pendingOwnerRequests = ownerReservations
        .where((reservation) => reservation.status == 'pending')
        .length;

    final returnConfirmations = ownerReservations
        .where(_needsReturnConfirmation)
        .length;

    final unreadOwnerMessages = ownerReservations
        .where(
          (reservation) =>
              reservation.status == 'accepted' &&
              reservation.hasUnreadMessageFor(uid),
        )
        .length;

    final unreadRenterMessages = renterReservations
        .where(
          (reservation) =>
              reservation.status == 'accepted' &&
              reservation.hasUnreadMessageFor(uid),
        )
        .length;

    return _NotificationData(
      pendingOwnerRequests: pendingOwnerRequests,
      returnConfirmations: returnConfirmations,
      unreadOwnerMessages: unreadOwnerMessages,
      unreadRenterMessages: unreadRenterMessages,
    );
  }

  String _badgeText(int count) {
    if (count > 99) return '99+';

    return count.toString();
  }

  Widget _badgedIcon(IconData icon, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(_badgeText(count)),
      child: Icon(icon),
    );
  }

  Widget _countText(int count) {
    return Text(
      count.toString(),
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  void _openTabFromSheet(BuildContext sheetContext, int tabIndex) {
    Navigator.of(sheetContext).pop();
    setState(() => _index = tabIndex);
  }

  void _showNotificationSheet(
    BuildContext context,
    _NotificationData notificationData,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final tiles = <Widget>[];

        if (notificationData.pendingOwnerRequests > 0) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Nieuwe reservatie-aanvragen'),
              subtitle: const Text('Ga naar je verhuurderdashboard.'),
              trailing: _countText(notificationData.pendingOwnerRequests),
              onTap: () => _openTabFromSheet(sheetContext, 3),
            ),
          );
        }

        if (notificationData.returnConfirmations > 0) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('Teruggave te bevestigen'),
              subtitle: const Text(
                'Een geaccepteerde reservatie is afgelopen.',
              ),
              trailing: _countText(notificationData.returnConfirmations),
              onTap: () => _openTabFromSheet(sheetContext, 3),
            ),
          );
        }

        if (notificationData.unreadOwnerMessages > 0) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.mark_chat_unread),
              title: const Text('Nieuwe berichten als verhuurder'),
              subtitle: const Text('Ga naar je verhuurderdashboard.'),
              trailing: _countText(notificationData.unreadOwnerMessages),
              onTap: () => _openTabFromSheet(sheetContext, 3),
            ),
          );
        }

        if (notificationData.unreadRenterMessages > 0) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.mark_chat_unread),
              title: const Text('Nieuwe berichten bij je reserveringen'),
              subtitle: const Text('Ga naar mijn reserveringen.'),
              trailing: _countText(notificationData.unreadRenterMessages),
              onTap: () => _openTabFromSheet(sheetContext, 2),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Meldingen',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (tiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Je hebt momenteel geen nieuwe meldingen.'),
                  )
                else
                  ...tiles,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(_NotificationData notificationData) {
    final reservationsBadgeCount = notificationData.unreadRenterMessages;

    final dashboardBadgeCount =
        notificationData.pendingOwnerRequests +
        notificationData.returnConfirmations +
        notificationData.unreadOwnerMessages;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: notificationData.total == 0
                ? 'Geen meldingen'
                : '${notificationData.total} melding(en)',
            onPressed: () => _showNotificationSheet(context, notificationData),
            icon: _badgedIcon(
              notificationData.total > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              notificationData.total,
            ),
          ),
          IconButton(
            tooltip: 'Uitloggen',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Zoeken',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Aanbieden',
          ),
          NavigationDestination(
            icon: _badgedIcon(Icons.event_outlined, reservationsBadgeCount),
            selectedIcon: _badgedIcon(Icons.event, reservationsBadgeCount),
            label: 'Reservaties',
          ),
          NavigationDestination(
            icon: _badgedIcon(Icons.dashboard_outlined, dashboardBadgeCount),
            selectedIcon: _badgedIcon(Icons.dashboard, dashboardBadgeCount),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reservationStreamFor(field: 'ownerId', uid: user.uid),
      builder: (context, ownerSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reservationStreamFor(field: 'renterId', uid: user.uid),
          builder: (context, renterSnapshot) {
            final ownerReservations = _reservationsFromSnapshot(ownerSnapshot);
            final renterReservations = _reservationsFromSnapshot(
              renterSnapshot,
            );

            final notificationData = _buildNotificationData(
              uid: user.uid,
              ownerReservations: ownerReservations,
              renterReservations: renterReservations,
            );

            return _buildScaffold(notificationData);
          },
        );
      },
    );
  }
}

class _NotificationData {
  final int pendingOwnerRequests;
  final int returnConfirmations;
  final int unreadOwnerMessages;
  final int unreadRenterMessages;

  const _NotificationData({
    required this.pendingOwnerRequests,
    required this.returnConfirmations,
    required this.unreadOwnerMessages,
    required this.unreadRenterMessages,
  });

  int get total {
    return pendingOwnerRequests +
        returnConfirmations +
        unreadOwnerMessages +
        unreadRenterMessages;
  }
}

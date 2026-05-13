import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/rental_reservation.dart';

class ReservationChatPage extends StatefulWidget {
  final RentalReservation reservation;

  const ReservationChatPage({super.key, required this.reservation});

  @override
  State<ReservationChatPage> createState() => _ReservationChatPageState();
}

class _ReservationChatPageState extends State<ReservationChatPage> {
  final _messageController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _reservationRef {
    return FirebaseFirestore.instance
        .collection('reservations')
        .doc(widget.reservation.id);
  }

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return _reservationRef.collection('messages');
  }

  bool _isParticipant(RentalReservation reservation) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    return reservation.ownerId == user.uid || reservation.renterId == user.uid;
  }

  bool _canSendMessages(RentalReservation reservation) {
    return _isParticipant(reservation) && reservation.status == 'accepted';
  }

  Future<void> _sendMessage(RentalReservation reservation) async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _messageController.text.trim();

    if (user == null) {
      _showMessage('Je moet ingelogd zijn om een bericht te sturen.');
      return;
    }

    if (!_canSendMessages(reservation)) {
      _showMessage(
        'Je kan alleen berichten sturen bij een geaccepteerde reservatie.',
      );
      return;
    }

    if (text.isEmpty) return;

    if (text.length > 1000) {
      _showMessage('Een bericht mag maximaal 1000 tekens bevatten.');
      return;
    }

    setState(() => _isSending = true);

    try {
      await _messagesRef.add({
        'senderId': user.uid,
        'senderEmail': user.email ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (error) {
      _showMessage('Bericht versturen mislukt: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return 'Net nu';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildClosedChatNotice(RentalReservation reservation) {
    if (reservation.status == 'accepted') {
      return const SizedBox.shrink();
    }

    String message = 'Deze chat is gesloten.';

    if (reservation.status == 'pending') {
      message = 'De chat opent zodra de reservatie geaccepteerd is.';
    } else if (reservation.status == 'returned') {
      message = 'Deze chat is gesloten omdat de teruggave bevestigd is.';
    } else if (reservation.status == 'rejected') {
      message = 'Deze chat is gesloten omdat de reservatie geweigerd is.';
    } else if (reservation.status == 'cancelled') {
      message = 'Deze chat is gesloten omdat de reservatie geannuleerd is.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.black12,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMine = currentUser != null && message.senderId == currentUser.uid;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'Jij' : message.senderEmail,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(message.text),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Fout: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs.map(ChatMessage.fromDoc).toList();

        if (messages.isEmpty) {
          return const Center(child: Text('Nog geen berichten.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(messages[index]);
          },
        );
      },
    );
  }

  Widget _buildInputBar(RentalReservation reservation) {
    final canSend = _canSendMessages(reservation);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: canSend && !_isSending,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: canSend
                      ? 'Typ een bericht...'
                      : 'Berichten sturen is niet beschikbaar.',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSend && !_isSending
                  ? () => _sendMessage(reservation)
                  : null,
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _reservationRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Berichten')),
            body: Center(child: Text('Fout: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Berichten')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;

        if (!doc.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Berichten')),
            body: const Center(
              child: Text('Deze reservatie bestaat niet meer.'),
            ),
          );
        }

        final reservation = RentalReservation.fromDoc(doc);

        return Scaffold(
          appBar: AppBar(
            title: Text('Berichten: ${reservation.applianceTitle}'),
          ),
          body: Column(
            children: [
              _buildClosedChatNotice(reservation),
              Expanded(child: _buildMessagesList()),
              _buildInputBar(reservation),
            ],
          ),
        );
      },
    );
  }
}

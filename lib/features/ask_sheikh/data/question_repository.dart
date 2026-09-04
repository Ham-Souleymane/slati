import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/question_model.dart';

class QuestionRepository {
  QuestionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const MethodChannel _nativeChannel =
      MethodChannel('com.slatk.slatkapp/adhan');

  CollectionReference<Map<String, dynamic>> get _questions =>
      _firestore.collection('questions');

  // ── Worshipper reads ──────────────────────────────────────────

  /// Watches all questions submitted by a given user, newest first.
  Stream<List<QuestionModel>> watchMyQuestions(String userId) {
    return _questions
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(QuestionModel.fromFirestore).toList();
      list.sort((a, b) {
        final aDate = a.lastActivityAt ?? a.createdAt;
        final bDate = b.lastActivityAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  /// Watches a single question by ID.
  Stream<QuestionModel?> watchQuestion(String questionId) {
    return _questions.doc(questionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return QuestionModel.fromFirestore(doc);
    });
  }

  /// Count of unanswered questions for a user (for badge display).
  Stream<int> watchUnansweredCount(String userId) {
    return _questions
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: QuestionStatus.pending.value)
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── Worshipper writes ─────────────────────────────────────────

  /// Submits a new question. Returns the created document ID.
  Future<String> submitQuestion(QuestionModel question) async {
    final ref = await _questions.add(question.toFirestore());
    // Best-effort FCM via native channel (no crash if unavailable)
    try {
      await _nativeChannel.invokeMethod('sendQuestionNotification', {
        'imamId': question.imamId,
        'questionId': ref.id,
        'title': question.title,
        'field': question.field,
      });
    } catch (_) {
      // FCM will be handled by Cloud Functions in production
    }
    return ref.id;
  }

  /// Submits a follow-up question by the worshipper.
  Future<void> submitFollowUpQuestion({
    required String questionId,
    required String message,
    required String userId,
    required String userDisplayName,
    String? userPhotoUrl,
  }) async {
    final reply = QuestionReply(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: userId,
      senderRole: 'user',
      senderName: userDisplayName,
      senderPhotoUrl: userPhotoUrl,
      message: message,
      createdAt: DateTime.now(),
    );

    final docRef = _questions.doc(questionId);
    await docRef.update({
      'replies': FieldValue.arrayUnion([reply.toMap()]),
      'status': QuestionStatus.pending.value,
      'isReadByAsker': true,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    // Best-effort notification to imam
    try {
      final doc = await docRef.get();
      final imamId = doc.data()?['imamId'] as String?;
      final title = doc.data()?['title'] as String?;
      final field = doc.data()?['field'] as String?;
      if (imamId != null && imamId.isNotEmpty) {
        await _nativeChannel.invokeMethod('sendQuestionNotification', {
          'imamId': imamId,
          'questionId': questionId,
          'title': 'استفسار جديد: ${title ?? ''}',
          'field': field ?? '',
        });
      }
    } catch (_) {}
  }

  /// Marks the answer as read by the asker.
  Future<void> markAnswerRead(String questionId) async {
    await _questions.doc(questionId).update({'isReadByAsker': true});
  }

  // ── Imam reads (Minbar) ───────────────────────────────────────

  /// Watches all questions assigned to a given imam, newest first.
  Stream<List<QuestionModel>> watchImamQuestions(
    String imamId, {
    String? field,
    QuestionStatus? status,
  }) {
    Query<Map<String, dynamic>> q =
        _questions.where('imamId', isEqualTo: imamId);

    if (status != null) {
      q = q.where('status', isEqualTo: status.value);
    }

    return q.snapshots().map((snap) {
      final list = snap.docs.map(QuestionModel.fromFirestore).toList();
      list.sort((a, b) {
        final aDate = a.lastActivityAt ?? a.createdAt;
        final bDate = b.lastActivityAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      if (field != null && field.isNotEmpty) {
        return list.where((q) => q.field == field).toList();
      }
      return list;
    });
  }

  /// Count of new (pending, unread) questions for an imam.
  Stream<int> watchNewQuestionsCount(String imamId) {
    return _questions
        .where('imamId', isEqualTo: imamId)
        .where('status', isEqualTo: QuestionStatus.pending.value)
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── Imam writes (Minbar) ──────────────────────────────────────

  /// Posts the imam's initial answer. Updates status → answered.
  Future<void> submitAnswer({
    required String questionId,
    required String answer,
    required String imamId,
  }) async {
    final batch = _firestore.batch();

    // Update the question document
    batch.update(_questions.doc(questionId), {
      'answer': answer,
      'status': QuestionStatus.answered.value,
      'answeredAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
      'isReadByAsker': false,
    });

    await batch.commit();

    // Best-effort FCM to the worshipper
    try {
      final doc = await _questions.doc(questionId).get();
      final userId = doc.data()?['userId'] as String?;
      if (userId != null) {
        await _nativeChannel.invokeMethod('sendAnswerNotification', {
          'userId': userId,
          'questionId': questionId,
          'imamId': imamId,
        });
      }
    } catch (_) {}
  }

  /// Submits a follow-up answer by the imam.
  Future<void> submitFollowUpAnswer({
    required String questionId,
    required String message,
    required String imamId,
    required String imamName,
    String? imamPhotoUrl,
  }) async {
    final reply = QuestionReply(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: imamId,
      senderRole: 'imam',
      senderName: imamName,
      senderPhotoUrl: imamPhotoUrl,
      message: message,
      createdAt: DateTime.now(),
    );

    final docRef = _questions.doc(questionId);
    await docRef.update({
      'replies': FieldValue.arrayUnion([reply.toMap()]),
      'status': QuestionStatus.answered.value,
      'isReadByAsker': false,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    // Best-effort notification to worshipper
    try {
      final doc = await docRef.get();
      final userId = doc.data()?['userId'] as String?;
      if (userId != null) {
        await _nativeChannel.invokeMethod('sendAnswerNotification', {
          'userId': userId,
          'questionId': questionId,
          'imamId': imamId,
        });
      }
    } catch (_) {}
  }

  /// Rejects a question (e.g. off-topic or inappropriate).
  Future<void> rejectQuestion(String questionId) async {
    await _questions.doc(questionId).update({
      'status': QuestionStatus.rejected.value,
    });
  }
}

// ── Providers ─────────────────────────────────────────────────

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository(ref.watch(firestoreProvider));
});

/// Worshipper's question stream.
final myQuestionsProvider = StreamProvider<List<QuestionModel>>((ref) {
  // Use ref.watch so this provider rebuilds whenever auth state resolves
  // (sign-in, sign-out, or initial resolution after app start).
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.read(questionRepositoryProvider).watchMyQuestions(user.uid);
});

/// Count of worshipper's pending (unanswered) questions — for badge.
final pendingQuestionsCountProvider = StreamProvider<int>((ref) {
  // Use ref.watch so this provider rebuilds whenever auth state resolves.
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(0);
  return ref
      .read(questionRepositoryProvider)
      .watchUnansweredCount(user.uid);
});

/// Imam's incoming question stream (Minbar).
final imamQuestionsProvider =
    StreamProvider.family<List<QuestionModel>, String>((ref, imamId) {
  if (imamId.isEmpty) return Stream.value([]);
  return ref
      .watch(questionRepositoryProvider)
      .watchImamQuestions(imamId);
});

/// Count of new questions for an imam — for badge (Minbar).
final newImamQuestionsCountProvider =
    StreamProvider.family<int, String>((ref, imamId) {
  if (imamId.isEmpty) return Stream.value(0);
  return ref
      .watch(questionRepositoryProvider)
      .watchNewQuestionsCount(imamId);
});

/// Single question stream by ID.
final questionByIdProvider =
    StreamProvider.family<QuestionModel?, String>((ref, questionId) {
  if (questionId.isEmpty) return Stream.value(null);
  return ref.watch(questionRepositoryProvider).watchQuestion(questionId);
});

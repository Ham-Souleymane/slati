import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a question in the Q&A lifecycle.
enum QuestionStatus {
  pending,
  answered,
  rejected;

  static QuestionStatus fromString(String? s) {
    switch (s) {
      case 'answered':
        return answered;
      case 'rejected':
        return rejected;
      default:
        return pending;
    }
  }

  String get value {
    switch (this) {
      case pending:
        return 'pending';
      case answered:
        return 'answered';
      case rejected:
        return 'rejected';
    }
  }

  String labelAr() {
    switch (this) {
      case pending:
        return 'قيد الانتظار';
      case answered:
        return 'تمت الإجابة';
      case rejected:
        return 'مرفوض';
    }
  }
}

/// Represents a follow-up message in a question thread.
class QuestionReply {
  const QuestionReply({
    required this.id,
    required this.senderId,
    required this.senderRole, // 'user' or 'imam'
    required this.senderName,
    this.senderPhotoUrl,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String? senderPhotoUrl;
  final String message;
  final DateTime createdAt;

  bool get isFromUser => senderRole == 'user';
  bool get isFromImam => senderRole == 'imam';

  factory QuestionReply.fromMap(Map<String, dynamic> map) {
    return QuestionReply(
      id: (map['id'] as String?) ?? '',
      senderId: (map['senderId'] as String?) ?? '',
      senderRole: (map['senderRole'] as String?) ?? 'user',
      senderName: (map['senderName'] as String?) ?? '',
      senderPhotoUrl: map['senderPhotoUrl'] as String?,
      message: (map['message'] as String?) ?? '',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is String)
              ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderRole': senderRole,
      'senderName': senderName,
      if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Immutable model for the `questions` Firestore collection.
class QuestionModel {
  const QuestionModel({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.isAnonymous,
    required this.imamId,
    required this.imamName,
    required this.field,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.imamPhotoUrl,
    this.answer,
    this.answeredAt,
    this.isReadByAsker = false,
    this.replies = const [],
    this.lastActivityAt,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final bool isAnonymous;

  /// References `imams/{imamId}`.
  final String imamId;
  final String imamName;
  final String? imamPhotoUrl;

  /// One of the IslamicField IDs (e.g. 'fiqh').
  final String field;
  final String title;
  final String body;
  final QuestionStatus status;
  final String? answer;
  final DateTime? answeredAt;
  final DateTime createdAt;
  final bool isReadByAsker;

  /// Thread of follow-up messages between worshipper and imam.
  final List<QuestionReply> replies;
  final DateTime? lastActivityAt;

  bool get isAnswered => status == QuestionStatus.answered;
  bool get isPending => status == QuestionStatus.pending;
  bool get hasFollowUps => replies.isNotEmpty;
  bool get isFollowUpPending =>
      status == QuestionStatus.pending && answer != null;
  bool get canUserAskFollowUp => status == QuestionStatus.answered;

  QuestionReply? get latestReply => replies.isNotEmpty ? replies.last : null;

  // ── Firestore deserialization ─────────────────────────────────
  factory QuestionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    final rawReplies = d['replies'] as List<dynamic>?;
    final replies = rawReplies != null
        ? rawReplies
            .map((r) {
              if (r is Map) {
                return QuestionReply.fromMap(Map<String, dynamic>.from(r));
              }
              return null;
            })
            .whereType<QuestionReply>()
            .toList()
        : <QuestionReply>[];

    return QuestionModel(
      id: doc.id,
      userId: (d['userId'] as String?) ?? '',
      userDisplayName: (d['userDisplayName'] as String?) ?? 'مجهول',
      isAnonymous: (d['isAnonymous'] as bool?) ?? false,
      imamId: (d['imamId'] as String?) ?? '',
      imamName: (d['imamName'] as String?) ?? '',
      imamPhotoUrl: d['imamPhotoUrl'] as String?,
      field: (d['field'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      status: QuestionStatus.fromString(d['status'] as String?),
      answer: d['answer'] as String?,
      answeredAt: (d['answeredAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReadByAsker: (d['isReadByAsker'] as bool?) ?? false,
      replies: replies,
      lastActivityAt: (d['lastActivityAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Firestore serialization ───────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'isAnonymous': isAnonymous,
      'imamId': imamId,
      'imamName': imamName,
      if (imamPhotoUrl != null) 'imamPhotoUrl': imamPhotoUrl,
      'field': field,
      'title': title,
      'body': body,
      'status': status.value,
      if (answer != null) 'answer': answer,
      if (answeredAt != null)
        'answeredAt': Timestamp.fromDate(answeredAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'isReadByAsker': isReadByAsker,
      'replies': replies.map((r) => r.toMap()).toList(),
      if (lastActivityAt != null)
        'lastActivityAt': Timestamp.fromDate(lastActivityAt!),
    };
  }

  QuestionModel copyWith({
    QuestionStatus? status,
    String? answer,
    DateTime? answeredAt,
    bool? isReadByAsker,
    List<QuestionReply>? replies,
    DateTime? lastActivityAt,
  }) {
    return QuestionModel(
      id: id,
      userId: userId,
      userDisplayName: userDisplayName,
      isAnonymous: isAnonymous,
      imamId: imamId,
      imamName: imamName,
      imamPhotoUrl: imamPhotoUrl,
      field: field,
      title: title,
      body: body,
      status: status ?? this.status,
      answer: answer ?? this.answer,
      answeredAt: answeredAt ?? this.answeredAt,
      createdAt: createdAt,
      isReadByAsker: isReadByAsker ?? this.isReadByAsker,
      replies: replies ?? this.replies,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}

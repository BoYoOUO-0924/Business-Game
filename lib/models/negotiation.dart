enum NegotiationStatus {
  ongoing,
  agreed,
  counterOffer,
  rejected,
}

class NegotiationMessage {
  final String sender;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final NegotiationOutcome? outcome;

  NegotiationMessage({
    required this.sender,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.outcome,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NegotiationOutcome {
  final NegotiationStatus status;
  final double agreedUnitPrice;
  final int relationshipChange;
  final String dialogue;
  final String reasoning;

  NegotiationOutcome({
    required this.status,
    required this.agreedUnitPrice,
    required this.relationshipChange,
    required this.dialogue,
    required this.reasoning,
  });

  factory NegotiationOutcome.fromMap(Map<String, dynamic> map) {
    NegotiationStatus parseStatus(String s) {
      switch (s) {
        case 'accepted':
          return NegotiationStatus.agreed;
        case 'counter_offer':
          return NegotiationStatus.counterOffer;
        case 'rejected':
        default:
          return NegotiationStatus.rejected;
      }
    }

    return NegotiationOutcome(
      status: parseStatus(map['status'] ?? 'counter_offer'),
      agreedUnitPrice: (map['final_unit_price'] as num?)?.toDouble() ?? 100.0,
      relationshipChange: (map['relationship_change'] as num?)?.toInt() ?? 0,
      dialogue: map['dialogue'] ?? '',
      reasoning: map['reasoning'] ?? '',
    );
  }
}

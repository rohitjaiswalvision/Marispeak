class Event {
  final String event;
  final Map<String, dynamic>? body;

  Event({
    required this.event,
    this.body,
    
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      event: map['event'] ?? '',
      body: Map<String, dynamic>.from(map['body'] ?? {}),
    );
  }
}

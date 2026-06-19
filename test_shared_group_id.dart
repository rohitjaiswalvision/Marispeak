// Test script to verify shared group ID generation

String getSharedChannelID(String userId1, String userId2) {
  List<String> ids = [userId1, userId2]..sort();
  return ids.join('_');
}

void main() {
  String user1 = "PHQ7BYxi9jOpXmi4LkpLD37WOYo2";
  String user2 = "ajaw9LhcwUSp5tyoVXorVYV8N473";

  // Test from User 1's perspective
  String groupFromUser1 = getSharedChannelID(user1, user2);
  print("User 1 generates: $groupFromUser1");

  // Test from User 2's perspective
  String groupFromUser2 = getSharedChannelID(user2, user1);
  print("User 2 generates: $groupFromUser2");

  // Verify they match
  if (groupFromUser1 == groupFromUser2) {
    print("✅ SUCCESS: Both users generate the SAME group ID!");
  } else {
    print("❌ FAIL: Group IDs don't match!");
  }

  print("\nExpected group ID:");
  print(groupFromUser1);
}

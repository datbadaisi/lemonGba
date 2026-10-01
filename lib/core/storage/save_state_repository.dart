/// Persistent save-state operations for a single game identity.
abstract interface class SaveStateRepository {
  int get quickSlotCount;
  int get manualSlotCount;
  Future<void> prepareGame(String gameId);
  Future<int?> mostRecentQuickSlot(String gameId);
  Future<int> nextQuickSlot(String gameId);
  Future<void> recordQuickSlot(String gameId, int slot);
  Future<List<DateTime?>> quickSlotTimes(String gameId);
  Future<List<DateTime?>> manualSlotTimes(String gameId);
  Future<bool> saveQuick(String gameId, int slot, List<int> bytes);
  Future<List<int>?> loadQuick(String gameId, int slot);
  Future<bool> saveManual(String gameId, int slot, List<int> bytes);
  Future<List<int>?> loadManual(String gameId, int slot);
}

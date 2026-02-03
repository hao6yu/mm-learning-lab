import 'package:flutter/foundation.dart';
import '../models/profile.dart';
import '../services/database_service.dart';

class ProfileProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Profile> _profiles = [];
  int? _selectedProfileId;

  List<Profile> get profiles => _profiles;
  int? get selectedProfileId => _selectedProfileId;

  Future<void> loadProfiles() async {
    _profiles = await _db.getProfiles();
    notifyListeners();
  }

  Future<void> addProfile(Profile profile) async {
    final id = await _db.insertProfile(profile);
    final newProfile = Profile(
      id: id,
      name: profile.name,
      age: profile.age,
      avatar: profile.avatar,
      createdAt: profile.createdAt,
    );
    _profiles.add(newProfile);
    notifyListeners();
  }

  void selectProfile(int? id) {
    _selectedProfileId = id;
    notifyListeners();
  }

  Future<void> updateProfile(Profile profile) async {
    await _db.updateProfile(profile);
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      notifyListeners();
    }
  }

  Future<void> deleteProfile(int id) async {
    await _db.deleteProfile(id);
    _profiles.removeWhere((profile) => profile.id == id);
    if (_selectedProfileId == id) {
      _selectedProfileId = null;
    }
    notifyListeners();
  }

  Future<void> resetDatabase() async {
    await _db.deleteDatabase();
    _profiles = [];
    _selectedProfileId = null;
    notifyListeners();
  }
}

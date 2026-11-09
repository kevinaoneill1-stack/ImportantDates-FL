import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/flavor.dart';
import '../models/important_date.dart';
import 'attachment_sync.dart';
import 'cloud_sync.dart';
import 'drive_sync.dart';

/// What the rest of the app needs to know about sync, whichever service the
/// build uses (Firebase in the personal edition, Google Drive in the public
/// one).
abstract interface class SyncState implements Listenable {
  /// Set up, signed in and switched on.
  bool get isSyncOn;

  /// Actively syncing this device.
  bool get running;

  /// One line for App Settings › Data & Sync Status.
  String get statusSummary;

  /// The signed-in account (email), if any.
  String? get accountLabel;

  /// Lets the next sync delete many records at once (Delete All Data,
  /// Restore Backup).
  void allowBulkDeleteOnce();
}

/// Attachment files kept in the cloud.
abstract interface class AttachmentCloud implements Listenable {
  /// Attachment ids downloading right now.
  Set<String> get downloading;

  bool isOnDevice(ItemAttachment a);

  /// The file has a cloud copy.
  bool isInCloud(ItemAttachment a);

  /// The file on this device, downloading it first if needed. Null when it is
  /// neither on this device nor in the cloud.
  Future<File?> ensureLocal(ItemAttachment a);

  /// Attachments that are in the cloud but not on this device.
  int get cloudOnlyCount;

  /// Downloads every cloud-only attachment. Returns (downloaded, failed).
  Future<(int, int)> downloadAll();
}

/// The sync service of this build.
class Sync {
  Sync._();

  static SyncState get state {
    if (Flavor.usesGoogleDrive) return DriveSync.instance;
    return CloudSync.instance;
  }

  static AttachmentCloud get attachments {
    if (Flavor.usesGoogleDrive) return DriveSync.instance;
    return AttachmentSync.instance;
  }
}

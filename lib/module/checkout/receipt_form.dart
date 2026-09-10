import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Cap on the receipt image, matching the guidance printed beside the tiles.
///
/// The same 5 MB the prescription form allows. A screenshot of a banking app
/// is nowhere near it; the cap is there for the member who attaches a video
/// or a scan at print resolution.
const int kReceiptMaxBytes = 5 * 1024 * 1024;

/// Written next to the cap wherever it is mentioned, so the number and the
/// words never drift apart.
const String kReceiptLimitLabel = '5 MB';

/// A file that has been chosen, reduced to what the form needs.
///
/// Not an [XFile]: the form is driven in tests where there is no gallery to
/// pick from and no file on disk to measure, and a plain set of values is
/// something a test can hand over.
@immutable
class PickedFile {
  final String name;

  /// The file's size, in bytes — what [ReceiptFormController.tooLarge] checks
  /// against the cap. Not the length of [data]: a test hands this over
  /// without any real content to measure.
  final int bytes;

  /// The file's actual content, read once at pick time so it can travel all
  /// the way to the order the receipt belongs to — a claim a person settles
  /// has to show the picture it was made on, on the admin side too. Null in
  /// every test (there is nothing to read bytes from), and best-effort in
  /// production: a read that fails still leaves the size and the name to
  /// submit, so a large or unreadable file does not block the receipt.
  final Uint8List? data;

  const PickedFile({required this.name, required this.bytes, this.data});
}

/// Opens the camera or the gallery.
///
/// A class rather than a bare call so it can be stood in for. There is no
/// gallery inside a widget test, so without a seam here the receipt form
/// could only ever be tested as far as the button that opens one — which is
/// the half of the flow that does not matter.
class ReceiptPicker {
  const ReceiptPicker();

  /// Replaces the real picker for the length of a test. Null in production,
  /// and nothing but a test may set it.
  @visibleForTesting
  static Future<PickedFile?> Function(ImageSource source)? debugOverride;

  Future<PickedFile?> pick(ImageSource source) async {
    final override = debugOverride;
    if (override != null) {
      return override(source);
    }
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) {
      return null;
    }
    Uint8List? data;
    try {
      data = await picked.readAsBytes();
    } catch (error) {
      // The size and the name still submit; only the picture itself is
      // missing on the admin side for this one receipt.
      debugPrint('ReceiptPicker: could not read the picked file — $error');
    }
    return PickedFile(
      name: picked.name,
      bytes: await picked.length(),
      data: data,
    );
  }
}

/// Everything the receipt form holds.
///
/// Kept apart from the widgets that draw it for the same reason the
/// prescription form is: the button that submits it sits in a bottom bar
/// outside the form, and it has to be able to ask whether the form is ready.
class ReceiptFormController extends ChangeNotifier {
  PickedFile? file;

  /// The bank's reference for the transfer — a UTR or a transaction ID.
  /// Mandatory: every UPI and bank app shows one the moment a transfer clears,
  /// and it is what lets a person at the other end match this submission to a
  /// line on the statement. See [PaymentReceipt.bankReference].
  String bankReference = '';

  bool busy = false;
  bool submitted = false;

  bool get tooLarge => (file?.bytes ?? 0) > kReceiptMaxBytes;

  /// A receipt picture within the size cap and the transfer's reference. Both
  /// are needed to act on the claim — the picture to look at, the reference to
  /// find the money against.
  bool get isComplete =>
      file != null && !tooLarge && bankReference.isNotEmpty;

  void setFile(PickedFile picked) {
    file = picked;
    notifyListeners();
  }

  void clearFile() {
    file = null;
    notifyListeners();
  }

  void setBankReference(String value) {
    bankReference = value.trim();
    notifyListeners();
  }

  void setBusy(bool value) {
    busy = value;
    notifyListeners();
  }
}

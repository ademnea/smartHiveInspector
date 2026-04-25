# Unit Test Report

Generated: 2026-04-25

| Test file | Test | What it checks | Result |
| --- | --- | --- | --- |
| `test/unit/profile_screen_test.dart` | `shows loaded profile details from the injected profile response` | Confirms `ProfileScreen` renders the user name, email, user ID, and role from a successful profile response. | Blocked: runner timed out before producing pass/fail output |
| `test/unit/profile_screen_test.dart` | `change password row explains that the feature is not wired yet` | Confirms tapping the profile screen `Change Password` row shows the current placeholder SnackBar message. | Blocked: runner timed out before producing pass/fail output |
| `test/unit/token_storage_test.dart` | `saveLoginData stores token, user fields, and profile payload` | Confirms login data and cached profile data are saved into `SharedPreferences` through `TokenStorage`. | Blocked: runner timed out before producing pass/fail output |
| `test/unit/token_storage_test.dart` | `clearLoginData removes saved authentication and profile data` | Confirms logout cleanup removes saved auth, user, role, and profile values. | Blocked: runner timed out before producing pass/fail output |

## Latest Run

Command: `flutter test test/unit`

Result: Blocked. The Flutter/Dart tool did not produce test output before timing out.

Attempts:

- `flutter test test/unit` timed out after 120 seconds.
- `flutter test test/unit` timed out after 300 seconds.
- `cmd /c flutter test test\unit` timed out after 180 seconds.
- `dart --disable-dart-dev --version` also timed out after 60 seconds, which indicates the local Dart/Flutter toolchain is hanging before the test suite can execute.

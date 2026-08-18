
Building Windows application...                                 
CMake Warning (dev) at flutter/ephemeral/.plugin_symlinks/media_kit_libs_windows_audio/windows/CMakeLists.txt:89 (add_custom_command):
  Exactly one of PRE_BUILD, PRE_LINK, or POST_BUILD must be given.  Assuming
  POST_BUILD to preserve backward compatibility.

  Policy CMP0175 is not set: add_custom_command() rejects invalid arguments.
  Run "cmake --help-policy CMP0175" for policy details.  Use the cmake_policy
  command to set the policy and suppress this warning.
This warning is for project developers.  Use -Wno-dev to suppress it.

lib/screens/screen/player_screen.dart(721,49): error G4127D1E8: The getter 'LaunchMode' isn't defined for the type '_ExternalLinkControl'. [D:\a\Music_Deewane\Music_Deewane\build\windows\x64\flutter\flutter_assemble.vcxproj]
lib/screens/screen/player_screen.dart(721,17): error GE5CFE876: The method 'launchUrl' isn't defined for the type '_ExternalLinkControl'. [D:\a\Music_Deewane\Music_Deewane\build\windows\x64\flutter\flutter_assemble.vcxproj]
C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Microsoft\VC\v180\Microsoft.CppCommon.targets(254,5): error MSB8066: Custom build for 'D:\a\Music_Deewane\Music_Deewane\build\windows\x64\CMakeFiles\fd4b19196b9557c77a87df256cb978a3\flutter_windows.dll.rule;D:\a\Music_Deewane\Music_Deewane\build\windows\x64\CMakeFiles\a2e3642c08870a5e80b45ed028ac4e12\flutter_assemble.rule;D:\a\Music_Deewane\Music_Deewane\windows\flutter\CMakeLists.txt' exited with code 1. [D:\a\Music_Deewane\Music_Deewane\build\windows\x64\flutter\flutter_assemble.vcxproj]
Building Windows application...                                   362.5s
Build process failed.
Error: Process completed with exit code 1.Try `flutter pub outdated` for more information.
Building Linux application...                                   
ERROR: lib/screens/screen/player_screen.dart:721:49: Error: The getter 'LaunchMode' isn't defined for the type '_ExternalLinkControl'.
ERROR:  - '_ExternalLinkControl' is from 'package:music_deewane/screens/screen/player_screen.dart' ('lib/screens/screen/player_screen.dart').
ERROR: Try correcting the name to the name of an existing getter, or defining a getter or field named 'LaunchMode'.
ERROR:           await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
ERROR:                                                 ^^^^^^^^^^
ERROR: lib/screens/screen/player_screen.dart:721:17: Error: The method 'launchUrl' isn't defined for the type '_ExternalLinkControl'.
ERROR:  - '_ExternalLinkControl' is from 'package:music_deewane/screens/screen/player_screen.dart' ('lib/screens/screen/player_screen.dart').
ERROR: Try correcting the name to the name of an existing method, or defining a method named 'launchUrl'.
ERROR:           await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
ERROR:                 ^^^^^^^^^
ERROR: Target kernel_snapshot_program failed: Exception
Build process failed
Error: Process completed with exit code 1."Install CMake 3.22.1 v.3.22.1" complete.
"Install CMake 3.22.1 v.3.22.1" finished.
"de": 10 untranslated message(s).
"es": 10 untranslated message(s).
"hi": 10 untranslated message(s).
"ja": 10 untranslated message(s).
"ko": 10 untranslated message(s).
"zh": 10 untranslated message(s).
To see a detailed report, use the untranslated-messages-file 
option in the l10n.yaml file:
untranslated-messages-file: desiredFileName.txt
<other option>: <other selection> 


This will generate a JSON format file containing all messages that 
need to be translated.
lib/screens/screen/player_screen.dart:721:49: Error: The getter 'LaunchMode' isn't defined for the type '_ExternalLinkControl'.
 - '_ExternalLinkControl' is from 'package:music_deewane/screens/screen/player_screen.dart' ('lib/screens/screen/player_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'LaunchMode'.
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                                ^^^^^^^^^^
lib/screens/screen/player_screen.dart:721:17: Error: The method 'launchUrl' isn't defined for the type '_ExternalLinkControl'.
 - '_ExternalLinkControl' is from 'package:music_deewane/screens/screen/player_screen.dart' ('lib/screens/screen/player_screen.dart').
Try correcting the name to the name of an existing method, or defining a method named 'launchUrl'.
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                ^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command '/opt/hostedtoolcache/flutter/stable-3.44.9-x64/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 2m 8s
Running Gradle task 'assembleRelease'...                          130.1s
Gradle task assembleRelease failed with exit code 1
Error: Process completed with exit code 1.
0s
Analyzing Music_Deewane...                                      

warning • The declaration '_ExternalLinkControl' isn't referenced. Try removing the declaration of '_ExternalLinkControl' • lib/screens/screen/player_screen.dart:708:7 • unused_element
  error • The method 'launchUrl' isn't defined for the type '_ExternalLinkControl'. Try correcting the name to the name of an existing method, or defining a method named 'launchUrl' • lib/screens/screen/player_screen.dart:721:17 • undefined_method
  error • Undefined name 'LaunchMode'. Try correcting the name to one that is defined, or defining the name • lib/screens/screen/player_screen.dart:721:49 • undefined_identifier

3 issues found. (ran in 22.2s)
Error: Process completed with exit code 1.

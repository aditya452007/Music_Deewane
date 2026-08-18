/// Base class for all plugin-related exceptions.
sealed class PluginException implements Exception {
  /// The plugin ID involved, if known.
  final String? pluginId;

  /// Human-readable error message.
  final String message;

  /// Optional underlying error.
  final Object? cause;

  const PluginException({
    this.pluginId,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (pluginId != null) buffer.write(' [plugin: $pluginId]');
    if (cause != null) buffer.write(' (cause: $cause)');
    return buffer.toString();
  }
}

/// Thrown when attempting to execute a command on a plugin that is not loaded.
class PluginNotLoadedException extends PluginException {
  const PluginNotLoadedException({
    required super.pluginId,
    super.message = 'Plugin is not loaded',
  });
}

/// Thrown when a plugin command execution fails.
///
/// The [errorCode] may contain structured error info from Rust
/// (format: `"PLUGIN_ERROR::{ErrorVariant}::{message}"`).
class PluginExecutionException extends PluginException {
  /// Raw error string from Rust bridge.
  final String? errorCode;

  const PluginExecutionException({
    super.pluginId,
    required super.message,
    this.errorCode,
    super.cause,
  });
}

/// Thrown when plugin installation fails.
class PluginInstallException extends PluginException {
  const PluginInstallException({
    super.pluginId,
    required super.message,
    super.cause,
  });
}

class PluginCountryRestrictedException extends PluginInstallException {
  final String countryCode;
  final List<String> allowlist;

  const PluginCountryRestrictedException({
    required super.pluginId,
    required this.countryCode,
    required this.allowlist,
  }) : super(
          message:
              'Plugin "$pluginId" is not available in your country ($countryCode).',
        );
}

/// Thrown when a plugin cannot be found (not available in plugin directory).
class PluginNotFoundException extends PluginException {
  const PluginNotFoundException({
    required super.pluginId,
    super.message = 'Plugin not found',
  });
}

/// Thrown when a media ID cannot be parsed (missing "::" separator).
class MalformedMediaIdException extends PluginException {
  /// The raw ID that failed to parse.
  final String rawId;

  const MalformedMediaIdException({
    required this.rawId,
    super.message = 'Malformed media ID',
  });
}

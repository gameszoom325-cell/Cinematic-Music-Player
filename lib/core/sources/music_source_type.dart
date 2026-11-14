enum MusicSourceType {
  local,
  cloud,
  externalProvider;

  String get id {
    switch (this) {
      case MusicSourceType.local:
        return 'local';
      case MusicSourceType.cloud:
        return 'cloud';
      case MusicSourceType.externalProvider:
        return 'external';
    }
  }

  String get displayName {
    switch (this) {
      case MusicSourceType.local:
        return 'Local Storage';
      case MusicSourceType.cloud:
        return 'Private Cloud Vault';
      case MusicSourceType.externalProvider:
        return 'External Stream Provider';
    }
  }

  static MusicSourceType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'cloud':
        return MusicSourceType.cloud;
      case 'external':
      case 'externalprovider':
        return MusicSourceType.externalProvider;
      case 'local':
      default:
        return MusicSourceType.local;
    }
  }
}

enum MusicSourceType {
  local,
  cloud,
  online,
  catalog,
  youtube,
  jamendo,
  externalProvider;

  String get id {
    switch (this) {
      case MusicSourceType.local:
        return 'local';
      case MusicSourceType.cloud:
        return 'cloud';
      case MusicSourceType.online:
        return 'online';
      case MusicSourceType.catalog:
        return 'catalog';
      case MusicSourceType.youtube:
        return 'youtube';
      case MusicSourceType.jamendo:
        return 'jamendo';
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
      case MusicSourceType.online:
        return 'Online Music (InnerTubeX)';
      case MusicSourceType.catalog:
        return 'Bollywood & Global Catalog';
      case MusicSourceType.youtube:
        return 'YouTube Music';
      case MusicSourceType.jamendo:
        return 'Jamendo Music (Creative Commons)';
      case MusicSourceType.externalProvider:
        return 'External Stream Provider';
    }
  }

  static MusicSourceType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'cloud':
        return MusicSourceType.cloud;
      case 'online':
      case 'innertube':
      case 'innertubex':
        return MusicSourceType.online;
      case 'catalog':
      case 'bollywood':
      case 'datasets':
        return MusicSourceType.catalog;
      case 'youtube':
      case 'yt':
        return MusicSourceType.youtube;
      case 'jamendo':
        return MusicSourceType.jamendo;
      case 'external':
      case 'externalprovider':
        return MusicSourceType.externalProvider;
      case 'local':
      default:
        return MusicSourceType.local;
    }
  }
}

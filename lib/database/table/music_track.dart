import 'package:floor/floor.dart';

@Entity(tableName: 'music_track')
class MusicTrack {
  @PrimaryKey(autoGenerate: true)
  final int? id;
  
  @ColumnInfo(name: 'name')
  final String name;
  
  @ColumnInfo(name: 'remote_path')
  final String remotePath;
  
  @ColumnInfo(name: 'library_id')
  final int libraryId;
  
  @ColumnInfo(name: 'size')
  final int size;
  
  @ColumnInfo(name: 'sign')
  final String? sign;
  
  @ColumnInfo(name: 'thumb')
  final String? thumb;
  
  @ColumnInfo(name: 'modified')
  final int modified;
  
  @ColumnInfo(name: 'provider')
  final String provider;
  
  @ColumnInfo(name: 'server_url')
  final String serverUrl;
  
  @ColumnInfo(name: 'user_id')
  final String userId;
  
  @ColumnInfo(name: 'create_time')
  final int createTime;

  MusicTrack({
    this.id,
    required this.name,
    required this.remotePath,
    required this.libraryId,
    required this.size,
    this.sign,
    this.thumb,
    required this.modified,
    required this.provider,
    required this.serverUrl,
    required this.userId,
    required this.createTime,
  });
}

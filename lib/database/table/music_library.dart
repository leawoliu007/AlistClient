import 'package:floor/floor.dart';

@Entity(tableName: 'music_library')
class MusicLibrary {
  @PrimaryKey(autoGenerate: true)
  final int? id;
  
  @ColumnInfo(name: 'name')
  final String name;
  
  @ColumnInfo(name: 'remote_path')
  final String remotePath;
  
  @ColumnInfo(name: 'server_url')
  final String serverUrl;
  
  @ColumnInfo(name: 'user_id')
  final String userId;
  
  @ColumnInfo(name: 'create_time')
  final int createTime;

  @ColumnInfo(name: 'max_depth')
  final int maxDepth;

  MusicLibrary({
    this.id,
    required this.name,
    required this.remotePath,
    required this.serverUrl,
    required this.userId,
    required this.createTime,
    this.maxDepth = 4,
  });
}

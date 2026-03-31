import 'package:alist/database/table/music_library.dart';
import 'package:floor/floor.dart';

@dao
abstract class MusicLibraryDao {
  @Query('SELECT * FROM music_library WHERE server_url = :serverUrl AND user_id = :userId ORDER BY create_time DESC')
  Future<List<MusicLibrary>> findLibraries(String serverUrl, String userId);
  
  @Query('SELECT * FROM music_library WHERE server_url = :serverUrl AND user_id = :userId AND remote_path = :remotePath')
  Future<MusicLibrary?> findByPath(String serverUrl, String userId, String remotePath);

  @insert
  Future<int> insertLibrary(MusicLibrary library);

  @update
  Future<void> updateLibrary(MusicLibrary library);

  @delete
  Future<void> deleteLibrary(MusicLibrary library);
  
  @Query('DELETE FROM music_library WHERE id = :id')
  Future<void> deleteById(int id);
}

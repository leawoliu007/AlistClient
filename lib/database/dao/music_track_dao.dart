import 'package:alist/database/table/music_track.dart';
import 'package:floor/floor.dart';

@dao
abstract class MusicTrackDao {
  @Query('SELECT * FROM music_track WHERE library_id = :libraryId ORDER BY name ASC')
  Future<List<MusicTrack>> findTracksByLibraryId(int libraryId);
  
  @Query('SELECT * FROM music_track WHERE library_id = :libraryId AND remote_path = :remotePath')
  Future<MusicTrack?> findByLibraryAndPath(int libraryId, String remotePath);

  @insert
  Future<int> insertTrack(MusicTrack track);

  @update
  Future<void> updateTrack(MusicTrack track);

  @delete
  Future<void> deleteTrack(MusicTrack track);
  
  @Query('DELETE FROM music_track WHERE library_id = :libraryId')
  Future<void> deleteTracksByLibraryId(int libraryId);
  
  @transaction
  Future<void> replaceAllTracksForLibrary(int libraryId, List<MusicTrack> tracks) async {
    await deleteTracksByLibraryId(libraryId);
    for (var track in tracks) {
      await insertTrack(track);
    }
  }
}

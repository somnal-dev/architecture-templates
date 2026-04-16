package android.template.core.database

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Entity
data class LikedPost(
    @PrimaryKey
    val postId: Int
)

@Dao
interface LikedPostDao {
    @Query("SELECT * FROM likedpost")
    fun getAllLikedPosts(): Flow<List<LikedPost>>

    @Query("SELECT EXISTS(SELECT 1 FROM likedpost WHERE postId = :postId)")
    fun isPostLiked(postId: Int): Flow<Boolean>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLikedPost(likedPost: LikedPost)

    @Query("DELETE FROM likedpost WHERE postId = :postId")
    suspend fun deleteLikedPost(postId: Int)
}

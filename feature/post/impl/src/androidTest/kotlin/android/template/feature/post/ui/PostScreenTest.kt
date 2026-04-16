package android.template.feature.post.ui

import android.template.core.model.Post
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * UI tests for [PostScreen].
 */
@RunWith(AndroidJUnit4::class)
class PostScreenTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    @Before
    fun setup() {
        composeTestRule.setContent {
            PostScreen(FAKE_DATA, onToggleLike = {})
        }
    }
    @Test
    fun firstItem_exists() {
        composeTestRule.onNodeWithText(FAKE_DATA.first().title).assertExists().performClick()
    }
}

private val FAKE_DATA = listOf(
    Post(1, 1, "First Post", "Body of first post"),
    Post(2, 1, "Second Post", "Body of second post"),
    Post(3, 2, "Third Post", "Body of third post")
)

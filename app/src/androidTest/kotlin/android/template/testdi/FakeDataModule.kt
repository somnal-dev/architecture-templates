package android.template.testdi

import android.template.core.data.PostRepository
import android.template.core.data.di.DataModule
import android.template.core.data.di.FakePostRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [DataModule::class]
)
interface FakeDataModule {

    @Binds
    abstract fun bindRepository(
        fakeRepository: FakePostRepository
    ): PostRepository
}

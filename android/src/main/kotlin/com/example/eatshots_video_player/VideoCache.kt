package com.example.eatshots_video_player

import android.content.Context
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.CacheWriter
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

@OptIn(UnstableApi::class)
object VideoCache {
    private var cache: SimpleCache? = null

    @Synchronized
    fun getCache(context: Context): SimpleCache {
        if (cache == null) {
            val cacheDir = File(context.cacheDir, "eatshots_video_cache")
            val evictor = LeastRecentlyUsedCacheEvictor(200 * 1024 * 1024) // 200MB limit
            val databaseProvider = StandaloneDatabaseProvider(context)
            cache = SimpleCache(cacheDir, evictor, databaseProvider)
        }
        return cache!!
    }

    fun prefetch(context: Context, url: String, prefetchBytes: Long) {
        val uri = Uri.parse(url)
        val dataSpec = DataSpec.Builder()
            .setUri(uri)
            .setPosition(0)
            .setLength(prefetchBytes)
            .build()

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36")
            .setAllowCrossProtocolRedirects(true)

        val cacheDataSource = CacheDataSource.Factory()
            .setCache(getCache(context))
            .setUpstreamDataSourceFactory(httpDataSourceFactory)
            .createDataSource()

        Thread {
            try {
                val cacheWriter = CacheWriter(
                    cacheDataSource,
                    dataSpec,
                    null,
                    null
                )
                cacheWriter.cache()
                android.util.Log.d("VideoCache", "Successfully prefetched $prefetchBytes bytes for $url")
            } catch (e: Exception) {
                android.util.Log.e("VideoCache", "Prefetch failed for $url: ${e.message}")
            }
        }.start()
    }
}

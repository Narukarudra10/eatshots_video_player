package com.example.eatshots_video_player

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.telephony.TelephonyManager
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.CacheWriter
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter
import java.io.File
import java.util.concurrent.ConcurrentHashMap

@OptIn(UnstableApi::class)
object VideoCache {
    private var cache: SimpleCache? = null
    private val activePrefetches = ConcurrentHashMap<String, CacheWriter>()
    private var bandwidthMeter: DefaultBandwidthMeter? = null

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

    @Synchronized
    fun getBandwidthMeter(context: Context): DefaultBandwidthMeter {
        if (bandwidthMeter == null) {
            bandwidthMeter = DefaultBandwidthMeter.Builder(context).build()
        }
        return bandwidthMeter!!
    }

    fun prefetch(context: Context, url: String, prefetchBytes: Long) {
        if (activePrefetches.containsKey(url)) {
            android.util.Log.d("VideoCache", "Prefetch already active for $url")
            return
        }

        // Dynamic prefetch size based on bandwidth meter or network type
        val estimatedBitrate = getBandwidthMeter(context).bitrateEstimate
        val finalPrefetchBytes = if (estimatedBitrate > 0) {
            if (estimatedBitrate >= 10_000_000) { // >= 10 Mbps (WiFi / 5G speed)
                1500 * 1024L // 1.5 MB
            } else if (estimatedBitrate >= 2_000_000) { // >= 2 Mbps (4G speed)
                500 * 1024L // 500 KB
            } else {
                128 * 1024L // 128 KB
            }
        } else {
            // Fallback to connection-type based estimate
            val netType = getNetworkType(context)
            if (netType == "WIFI" || netType == "5G") {
                1500 * 1024L
            } else if (netType == "4G") {
                500 * 1024L
            } else {
                128 * 1024L
            }
        }

        val uri = Uri.parse(url)
        val dataSpec = DataSpec.Builder()
            .setUri(uri)
            .setPosition(0)
            .setLength(finalPrefetchBytes)
            .build()

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36")
            .setAllowCrossProtocolRedirects(true)
            .setTransferListener(getBandwidthMeter(context))

        val defaultDataSourceFactory = DefaultDataSource.Factory(context, httpDataSourceFactory)

        val cacheDataSource = CacheDataSource.Factory()
            .setCache(getCache(context))
            .setUpstreamDataSourceFactory(defaultDataSourceFactory)
            .createDataSource()

        val cacheWriter = CacheWriter(
            cacheDataSource,
            dataSpec,
            null,
            null
        )

        activePrefetches[url] = cacheWriter
        android.util.Log.d("VideoCache", "Starting prefetch for $url of $finalPrefetchBytes bytes (est bitrate: $estimatedBitrate)")

        Thread {
            try {
                cacheWriter.cache()
                android.util.Log.d("VideoCache", "Successfully prefetched $finalPrefetchBytes bytes for $url")
            } catch (e: Exception) {
                android.util.Log.e("VideoCache", "Prefetch failed or cancelled for $url: ${e.message}")
            } finally {
                activePrefetches.remove(url)
            }
        }.start()
    }

    fun cancelPrefetch(url: String) {
        val writer = activePrefetches.remove(url)
        if (writer != null) {
            android.util.Log.d("VideoCache", "Cancelling prefetch for $url")
            Thread {
                try {
                    writer.cancel()
                } catch (e: Exception) {
                    android.util.Log.e("VideoCache", "Error cancelling prefetch for $url: ${e.message}")
                }
            }.start()
        }
    }

    fun getNetworkType(context: Context): String {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return "NONE"
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val activeNetwork = cm.activeNetwork ?: return "NONE"
                val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return "NONE"
                
                if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || 
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                    return "WIFI"
                }
                
                if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                    val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                    var preciseType = TelephonyManager.NETWORK_TYPE_UNKNOWN
                    try {
                        preciseType = tm?.dataNetworkType ?: TelephonyManager.NETWORK_TYPE_UNKNOWN
                    } catch (se: SecurityException) {
                        // READ_PHONE_STATE permission is missing
                    }
                    
                    if (preciseType == TelephonyManager.NETWORK_TYPE_UNKNOWN) {
                        val bandwidth = capabilities.linkDownstreamBandwidthKbps
                        return if (bandwidth >= 25000) { // 25 Mbps
                            "5G"
                        } else if (bandwidth >= 3000) { // 3 Mbps
                            "4G"
                        } else {
                            "3G"
                        }
                    }
                    
                    return when (preciseType) {
                        TelephonyManager.NETWORK_TYPE_NR -> "5G"
                        TelephonyManager.NETWORK_TYPE_LTE,
                        TelephonyManager.NETWORK_TYPE_HSPAP,
                        TelephonyManager.NETWORK_TYPE_EHRPD -> "4G"
                        else -> {
                            val bandwidth = capabilities.linkDownstreamBandwidthKbps
                            if (bandwidth >= 3000) "4G" else "3G"
                        }
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                val activeNetworkInfo = cm.activeNetworkInfo
                if (activeNetworkInfo == null || !activeNetworkInfo.isConnected) return "NONE"
                
                @Suppress("DEPRECATION")
                val type = activeNetworkInfo.type
                if (type == ConnectivityManager.TYPE_WIFI || type == ConnectivityManager.TYPE_ETHERNET) {
                    return "WIFI"
                }
                if (type == ConnectivityManager.TYPE_MOBILE) {
                    @Suppress("DEPRECATION")
                    val subType = activeNetworkInfo.subtype
                    return when (subType) {
                        TelephonyManager.NETWORK_TYPE_LTE -> "4G"
                        TelephonyManager.NETWORK_TYPE_HSPAP,
                        TelephonyManager.NETWORK_TYPE_EHRPD -> "4G"
                        else -> "3G"
                    }
                }
            }
            "NONE"
        } catch (e: Exception) {
            android.util.Log.e("VideoCache", "Error detecting network type: ${e.message}")
            "NONE"
        }
    }
}

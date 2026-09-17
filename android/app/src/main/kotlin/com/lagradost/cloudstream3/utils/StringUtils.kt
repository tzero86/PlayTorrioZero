package com.lagradost.cloudstream3.utils

import java.net.URLDecoder
import java.net.URLEncoder

object StringUtils {
    @JvmStatic
    fun encodeUri(url: String): String = try {
        URLEncoder.encode(url, "UTF-8")
    } catch (_: Throwable) {
        url
    }

    @JvmStatic
    fun decodeUri(url: String): String = try {
        URLDecoder.decode(url, "UTF-8")
    } catch (_: Throwable) {
        url
    }

    @JvmStatic
    fun encodeUrl(url: String): String = encodeUri(url)

    @JvmStatic
    fun decodeUrl(url: String): String = decodeUri(url)

    @JvmStatic
    fun fixUrl(url: String, domain: String = ""): String {
        if (url.startsWith("http://") || url.startsWith("https://")) return url
        if (url.startsWith("//")) return "https:$url"
        return if (domain.isNotEmpty()) {
            val d = if (domain.endsWith("/")) domain.substring(0, domain.length - 1) else domain
            val u = if (url.startsWith("/")) url else "/$url"
            "$d$u"
        } else url
    }

    @JvmStatic
    fun fixUrlNull(url: String?, domain: String = ""): String? {
        if (url == null) return null
        return fixUrl(url, domain)
    }

    @JvmStatic
    fun getDomain(url: String): String {
        return try {
            val uri = java.net.URI(url)
            val domain = uri.host ?: ""
            if (domain.startsWith("www.")) domain.substring(4) else domain
        } catch (_: Throwable) {
            ""
        }
    }
}


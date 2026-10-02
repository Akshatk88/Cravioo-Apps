package com.cravioo.restaurant

/**
 * Whether the restaurant is currently looking at the app.
 *
 * Set from MainActivity's resume/pause. The FCM service reads it to decide who
 * owns a new order: the in-app dialog when the app is in front, the floating
 * overlay when it is not — otherwise both would fire for the same order.
 */
object AppForeground {
    @Volatile
    var isForeground: Boolean = false
}

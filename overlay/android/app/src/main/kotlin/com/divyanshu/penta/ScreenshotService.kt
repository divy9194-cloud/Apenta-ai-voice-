package com.divyanshu.penta

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/** Screenshot, lock screen, and typing or searching in other apps, only when the user asks. */
class ScreenshotService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: ScreenshotService? = null
    }

    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    fun lockScreen(): Boolean {
        return Build.VERSION.SDK_INT >= 28 && performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
    }

    private fun findEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable && node.isVisibleToUser) return node
        for (i in 0 until node.childCount) {
            val found = findEditable(node.getChild(i))
            if (found != null) return found
        }
        return null
    }

    private fun focusedField(): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        return root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: findEditable(root)
    }

    fun typeIntoFocused(text: String): Boolean {
        val node = focusedField() ?: return false
        var existing = node.text?.toString() ?: ""
        if (Build.VERSION.SDK_INT >= 26 && node.isShowingHintText) existing = ""
        val full = if (existing.isEmpty()) text else "$existing $text"
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, full)
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun labelOf(node: AccessibilityNodeInfo): String {
        val a = node.contentDescription?.toString() ?: ""
        val b = node.text?.toString() ?: ""
        return (a + " " + b).lowercase()
    }

    private fun findByLabel(node: AccessibilityNodeInfo?, word: String): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isVisibleToUser && labelOf(node).contains(word)) return node
        for (i in 0 until node.childCount) {
            val found = findByLabel(node.getChild(i), word)
            if (found != null) return found
        }
        return null
    }

    private fun clickNode(node: AccessibilityNodeInfo): Boolean {
        var current: AccessibilityNodeInfo? = node
        var hops = 0
        while (current != null && hops < 5) {
            if (current.isClickable) return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            current = current.parent
            hops++
        }
        return false
    }

    /** Makes sure a text box is focused, by tapping the app's search icon or box if needed. */
    fun openSearchBox(): Boolean {
        val root = rootInActiveWindow ?: return false
        if (root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) != null) return true
        val node = findByLabel(root, "search") ?: return false
        return clickNode(node)
    }

    /** Presses the keyboard's search/enter key, or taps a "search" button. */
    fun pressSearch(): Boolean {
        val root = rootInActiveWindow ?: return false
        val field = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (field != null && Build.VERSION.SDK_INT >= 30) {
            if (field.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)) return true
        }
        val button = findByLabel(root, "search") ?: return false
        return clickNode(button)
    }
}

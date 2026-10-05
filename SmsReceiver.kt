package com.mizani.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import kotlin.math.abs

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return

        val sender = messages.firstOrNull()?.displayOriginatingAddress ?: "رسالة بنكية"
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
        val parsed = parse(body, sender) ?: return

        val smsId = buildId(messages)
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.pending_sms"
        val current = JSONArray(prefs.getString(key, "[]") ?: "[]")

        for (i in 0 until current.length()) {
            if (current.optJSONObject(i)?.optString("smsId") == smsId) return
        }

        val item = JSONObject().apply {
            put("smsId", smsId)
            put("title", parsed.merchant)
            put("category", parsed.category)
            put("amount", parsed.amount)
            put("isIncome", parsed.isIncome)
            put("date", messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis())
            put("source", "sms_auto")
        }
        current.put(item)
        prefs.edit().putString(key, current.toString()).apply()
    }

    private fun buildId(messages: Array<SmsMessage>): String {
        val first = messages.firstOrNull()
        return "${first?.timestampMillis ?: 0}_${first?.displayOriginatingAddress ?: ""}_${abs(messages.hashCode())}"
    }

    private data class Parsed(
        val amount: Double,
        val isIncome: Boolean,
        val merchant: String,
        val category: String
    )

    private fun parse(raw: String, sender: String): Parsed? {
        val text = normalize(raw)
        val lower = text.lowercase(Locale.ROOT)
        val amount = extractAmount(text) ?: return null

        val incomeWords = listOf("إيداع", "ايداع", "تم إيداع", "تم ايداع", "credited", "credit", "deposit", "salary", "راتب", "تحويل وارد")
        val debitWords = listOf("خصم", "سحب", "شراء", "دفع", "تم خصم", "debit", "purchase", "payment", "withdraw", "transaction")
        val isIncome = incomeWords.any { lower.contains(it.lowercase(Locale.ROOT)) }
        if (!isIncome && debitWords.none { lower.contains(it.lowercase(Locale.ROOT)) }) return null

        val merchant = extractMerchant(text, sender)
        val category = classify("$merchant $text")
        return Parsed(amount, isIncome, merchant, category)
    }

    private fun normalize(input: String): String {
        val ar = "٠١٢٣٤٥٦٧٨٩"
        val en = "0123456789"
        var s = input
        for (i in ar.indices) s = s.replace(ar[i], en[i])
        return s.replace('٬', '.').replace(',', '.')
    }

    private fun extractAmount(s: String): Double? {
        val patterns = listOf(
            Regex("(?:OMR|ر\\.?\\s*ع|ريال\\s*عماني)\\s*([0-9]+(?:\\.[0-9]{1,3})?)", RegexOption.IGNORE_CASE),
            Regex("(?:amount|amt|المبلغ|بقيمة|بمبلغ)\\s*[:\\-]?\\s*([0-9]+(?:\\.[0-9]{1,3})?)", RegexOption.IGNORE_CASE),
            Regex("([0-9]+(?:\\.[0-9]{1,3})?)\\s*(?:OMR|ر\\.?\\s*ع|ريال)", RegexOption.IGNORE_CASE),
            Regex("(?<!\\d)([0-9]+\\.[0-9]{2,3})(?!\\d)")
        )
        for (p in patterns) {
            val m = p.find(s) ?: continue
            val group = m.groupValues.lastOrNull() ?: continue
            group.toDoubleOrNull()?.let { return it }
        }
        return null
    }

    private fun extractMerchant(s: String, sender: String): String {
        val patterns = listOf(
            Regex("(?:لدى|من|عند|merchant|at)\\s+([A-Za-z0-9\\u0600-\\u06FF&._ -]{2,40})", RegexOption.IGNORE_CASE),
            Regex("(?:from|to)\\s+([A-Za-z0-9\\u0600-\\u06FF&._ -]{2,40})", RegexOption.IGNORE_CASE)
        )
        for (p in patterns) {
            val m = p.find(s) ?: continue
            return m.groupValues[1].trim().split(Regex("\\s+(?:بطاقة|card|رقم|ending)\\b", RegexOption.IGNORE_CASE))[0].trim()
        }
        return sender.trim().ifEmpty { "عملية بنكية" }
    }

    private fun classify(text: String): String {
        val lower = text.lowercase(Locale.ROOT)
        val merchants = mapOf(
            "oman oil" to "وقود", "ooredoo" to "اتصالات", "omantel" to "اتصالات",
            "lulu" to "مشتريات", "lu lu" to "مشتريات", "carrefour" to "مشتريات",
            "nesto" to "مشتريات", "talabat" to "مطاعم", "mcdonald" to "مطاعم",
            "kfc" to "مطاعم", "starbucks" to "مطاعم", "shell" to "وقود",
            "al maha" to "وقود", "maha" to "وقود"
        )
        for ((key, value) in merchants) if (lower.contains(key)) return value
        if (listOf("fuel", "petrol", "وقود", "محطة").any { lower.contains(it) }) return "وقود"
        if (listOf("restaurant", "مطعم", "cafe", "مقهى").any { lower.contains(it) }) return "مطاعم"
        if (listOf("grocery", "سوبر", "بقالة").any { lower.contains(it) }) return "مشتريات"
        if (listOf("internet", "اتصالات", "mobile").any { lower.contains(it) }) return "اتصالات"
        return "أخرى"
    }
}

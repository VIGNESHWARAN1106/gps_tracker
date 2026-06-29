package com.example.gps_tracker

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "tracking_session.db"
        private const val DATABASE_VERSION = 1
        private const val TABLE_LOCATIONS = "locations"
        
        // Schema definition
        private const val COLUMN_ID = "id"
        private const val COLUMN_LATITUDE = "latitude"
        private const val COLUMN_LONGITUDE = "longitude"
        private const val COLUMN_TIMESTAMP = "timestamp"
        private const val COLUMN_ACCURACY = "accuracy"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTableStatement = ("CREATE TABLE $TABLE_LOCATIONS ("
                + "$COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "$COLUMN_LATITUDE REAL, "
                + "$COLUMN_LONGITUDE REAL, "
                + "$COLUMN_TIMESTAMP INTEGER, "
                + "$COLUMN_ACCURACY REAL)")
        db.execSQL(createTableStatement)
        Log.i("DatabaseHelper", "SYSTEM METRIC: SQLite schema initialized successfully.")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_LOCATIONS")
        onCreate(db)
    }

    fun insertLocation(latitude: Double, longitude: Double, timestamp: Long, accuracy: Float) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_LATITUDE, latitude)
            put(COLUMN_LONGITUDE, longitude)
            put(COLUMN_TIMESTAMP, timestamp)
            put(COLUMN_ACCURACY, accuracy)
        }
        
        val result = db.insert(TABLE_LOCATIONS, null, values)
        if (result == -1L) {
            Log.e("DatabaseHelper", "SYSTEM METRIC: Disk write failure during location insertion.")
        } else {
            Log.i("DatabaseHelper", "SYSTEM METRIC: Telemetry payload committed to disk -> Lat: $latitude, Lon: $longitude")
        }
        db.close()
    }
}
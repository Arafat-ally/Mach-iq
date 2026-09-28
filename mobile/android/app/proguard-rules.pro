# WorkManager's Room database is instantiated through reflection during Android
# startup. Its older consumer rules keep the class but not its constructor under
# R8 full mode, causing InitializationProvider to crash before Flutter starts.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

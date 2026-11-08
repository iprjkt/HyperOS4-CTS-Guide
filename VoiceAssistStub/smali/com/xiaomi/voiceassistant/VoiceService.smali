.class public Lcom/xiaomi/voiceassistant/VoiceService;
.super Landroid/app/Service;
.source "VoiceService.java"

# static fields
.field private static final TAG:Ljava/lang/String; = "VoiceService-CTS"
.field private static sLastCTSRealtime:J

# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/app/Service;-><init>()V

    return-void
.end method

.method public static triggerCTS()V
    .locals 8

    invoke-static {}, Landroid/os/SystemClock;->elapsedRealtime()J

    move-result-wide v0

    sget-wide v2, Lcom/xiaomi/voiceassistant/VoiceService;->sLastCTSRealtime:J

    sub-long v4, v0, v2

    const-wide/16 v6, 0x3e8

    cmp-long v2, v4, v6

    if-gez v2, :cond_debounce_ok

    const-string v0, "VoiceService-CTS"

    const-string v1, "triggerCTS: debounced (< 1s)"

    invoke-static {v0, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_debounce_ok
    sput-wide v0, Lcom/xiaomi/voiceassistant/VoiceService;->sLastCTSRealtime:J

    :try_start_0
    const-string v0, "VoiceService-CTS"

    const-string v1, "triggerCTS: dispatching Circle to Search..."

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    const-string v0, "android.os.ServiceManager"

    invoke-static {v0}, Ljava/lang/Class;->forName(Ljava/lang/String;)Ljava/lang/Class;

    move-result-object v0

    const-string v1, "getService"

    const/4 v2, 0x1

    new-array v3, v2, [Ljava/lang/Class;

    const-class v4, Ljava/lang/String;

    const/4 v5, 0x0

    aput-object v4, v3, v5

    invoke-virtual {v0, v1, v3}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v0

    new-array v1, v2, [Ljava/lang/Object;

    const-string v3, "contextual_search"

    aput-object v3, v1, v5

    const/4 v3, 0x0

    invoke-virtual {v0, v3, v1}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/os/IBinder;

    if-nez v0, :cond_cs_found

    const-string v0, "VoiceService-CTS"

    const-string v1, "triggerCTS: contextual_search service not found"

    invoke-static {v0, v1}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_cs_found
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;

    move-result-object v1
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catch_all

    :try_start_1
    const-string v4, "android.app.contextualsearch.IContextualSearchManager"

    invoke-virtual {v1, v4}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V

    invoke-virtual {v1, v2}, Landroid/os/Parcel;->writeInt(I)V

    invoke-virtual {v1, v5}, Landroid/os/Parcel;->writeInt(I)V

    const/4 v4, 0x3

    invoke-interface {v0, v4, v1, v3, v2}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    :try_end_1
    .catchall {:try_start_1 .. :try_end_1} :catch_parcel

    :try_start_2
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V

    const-string v0, "VoiceService-CTS"

    const-string v1, "triggerCTS: CTS triggered successfully"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    goto :goto_end

    :catch_parcel
    move-exception v0

    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V

    throw v0
    :try_end_2
    .catchall {:try_start_2 .. :try_end_2} :catch_all

    :catch_all
    move-exception v0

    const-string v1, "VoiceService-CTS"

    const-string v2, "triggerCTS: error triggering CTS"

    invoke-static {v1, v2, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    :goto_end
    return-void
.end method

# virtual methods
.method public onBind(Landroid/content/Intent;)Landroid/os/IBinder;
    .locals 1

    const/4 v0, 0x0

    return-object v0
.end method

.method public onStartCommand(Landroid/content/Intent;II)I
    .locals 5

    const-string v0, "VoiceService-CTS"

    const-string v1, "onStartCommand received -> starting foreground and triggering CTS"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    :try_start_fg
    const-class v0, Landroid/app/NotificationManager;

    invoke-virtual {p0, v0}, Lcom/xiaomi/voiceassistant/VoiceService;->getSystemService(Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/app/NotificationManager;

    if-eqz v0, :cond_skip_channel

    const-string v1, "cts_channel"

    const-string v2, "CTS"

    const/4 v3, 0x2

    new-instance v4, Landroid/app/NotificationChannel;

    invoke-direct {v4, v1, v2, v3}, Landroid/app/NotificationChannel;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;I)V

    invoke-virtual {v0, v4}, Landroid/app/NotificationManager;->createNotificationChannel(Landroid/app/NotificationChannel;)V

    :cond_skip_channel
    const-string v1, "cts_channel"

    new-instance v0, Landroid/app/Notification$Builder;

    invoke-direct {v0, p0, v1}, Landroid/app/Notification$Builder;-><init>(Landroid/content/Context;Ljava/lang/String;)V

    const v1, 0x108009b

    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setSmallIcon(I)Landroid/app/Notification$Builder;

    move-result-object v0

    invoke-virtual {v0}, Landroid/app/Notification$Builder;->build()Landroid/app/Notification;

    move-result-object v0

    const/16 v1, 0x3e9

    invoke-virtual {p0, v1, v0}, Lcom/xiaomi/voiceassistant/VoiceService;->startForeground(ILandroid/app/Notification;)V
    :try_end_fg
    .catchall {:try_start_fg .. :try_end_fg} :catch_fg

    goto :goto_trigger

    :catch_fg
    move-exception v0

    const-string v1, "VoiceService-CTS"

    const-string v2, "failed to startForeground"

    invoke-static {v1, v2, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    :goto_trigger
    invoke-static {}, Lcom/xiaomi/voiceassistant/VoiceService;->triggerCTS()V

    :try_start_stop
    const/4 v0, 0x1

    invoke-virtual {p0, v0}, Lcom/xiaomi/voiceassistant/VoiceService;->stopForeground(I)V

    invoke-virtual {p0}, Lcom/xiaomi/voiceassistant/VoiceService;->stopSelf()V
    :try_end_stop
    .catchall {:try_start_stop .. :try_end_stop} :catch_stop

    goto :goto_ret

    :catch_stop
    move-exception v0

    const-string v1, "VoiceService-CTS"

    const-string v2, "failed to stopForeground/stopSelf"

    invoke-static {v1, v2, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    :goto_ret
    const/4 v0, 0x2

    return v0
.end method

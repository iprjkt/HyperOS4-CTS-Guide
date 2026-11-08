.class public Lcom/xiaomi/voiceassistant/PermissionVoiceService;
.super Landroid/app/Service;
.source "PermissionVoiceService.java"

# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/app/Service;-><init>()V

    return-void
.end method


# virtual methods
.method public onBind(Landroid/content/Intent;)Landroid/os/IBinder;
    .locals 1

    const/4 v0, 0x0

    return-object v0
.end method

.method public onStartCommand(Landroid/content/Intent;II)I
    .locals 1

    invoke-static {}, Lcom/xiaomi/voiceassistant/VoiceService;->triggerCTS()V

    invoke-virtual {p0}, Lcom/xiaomi/voiceassistant/PermissionVoiceService;->stopSelf()V

    const/4 v0, 0x2

    return v0
.end method

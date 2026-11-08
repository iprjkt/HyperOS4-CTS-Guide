.class public Lcom/xiaomi/voiceassistant/AssistInteractionSessionService;
.super Landroid/service/voice/VoiceInteractionSessionService;
.source "AssistInteractionSessionService.java"

# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/service/voice/VoiceInteractionSessionService;-><init>()V

    return-void
.end method

.method public onNewSession(Landroid/os/Bundle;)Landroid/service/voice/VoiceInteractionSession;
    .locals 1

    new-instance v0, Lcom/xiaomi/voiceassistant/AssistInteractionSession;

    invoke-direct {v0, p0}, Lcom/xiaomi/voiceassistant/AssistInteractionSession;-><init>(Landroid/content/Context;)V

    return-object v0
.end method

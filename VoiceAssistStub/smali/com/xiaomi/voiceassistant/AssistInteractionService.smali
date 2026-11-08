.class public Lcom/xiaomi/voiceassistant/AssistInteractionService;
.super Landroid/service/voice/VoiceInteractionService;
.source "AssistInteractionService.java"

# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/service/voice/VoiceInteractionService;-><init>()V

    return-void
.end method

.method public onReady()V
    .locals 2

    invoke-super {p0}, Landroid/service/voice/VoiceInteractionService;->onReady()V

    const-string v0, "AssistInteractionService"

    const-string v1, "onReady"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void
.end method

.method public onLaunchVoiceAssistFromKeyguard()V
    .locals 0

    invoke-static {}, Lcom/xiaomi/voiceassistant/VoiceService;->triggerCTS()V

    return-void
.end method

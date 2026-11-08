.class public Lcom/xiaomi/voiceassistant/AssistInteractionSession;
.super Landroid/service/voice/VoiceInteractionSession;
.source "AssistInteractionSession.java"

# direct methods
.method public constructor <init>(Landroid/content/Context;)V
    .locals 0

    invoke-direct {p0, p1}, Landroid/service/voice/VoiceInteractionSession;-><init>(Landroid/content/Context;)V

    return-void
.end method

.method public onShow(Landroid/os/Bundle;I)V
    .locals 0

    invoke-super {p0, p1, p2}, Landroid/service/voice/VoiceInteractionSession;->onShow(Landroid/os/Bundle;I)V

    invoke-static {}, Lcom/xiaomi/voiceassistant/VoiceService;->triggerCTS()V

    invoke-virtual {p0}, Landroid/service/voice/VoiceInteractionSession;->hide()V

    return-void
.end method

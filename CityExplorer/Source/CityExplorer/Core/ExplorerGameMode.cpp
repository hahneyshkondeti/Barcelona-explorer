#include "ExplorerGameMode.h"
#include "ExplorerMapSubsystem.h"
#include "ExplorerSessionSubsystem.h"
#include "../Vehicles/ExplorerVehicle.h"
#include "../World/ExplorerWorldSubsystem.h"
#include "../UI/ExplorerAppWidget.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Misc/CoreDelegates.h"
#include "TimerManager.h"
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
#include "../Tests/ExplorerPhysicsProbe.h"
#include "Components/InputComponent.h"
#include "UObject/ConstructorHelpers.h"
#include "Engine/GameViewportClient.h"
#include "Framework/Application/SlateApplication.h"
#include "Framework/Application/IInputProcessor.h"
#include "Layout/WidgetPath.h"
#include "Widgets/SWindow.h"
namespace {
class FExplorerInputTrace : public IInputProcessor
{
public:
    virtual void Tick(float, FSlateApplication&, TSharedRef<ICursor>) override {}
    virtual bool HandleKeyDownEvent(FSlateApplication& App, const FKeyEvent& Event) override
    {
        if (Event.GetKey() == EKeys::Tab || Event.GetKey() == EKeys::Enter || Event.GetKey() == EKeys::Down || Event.GetKey() == EKeys::Escape)
        {
            auto Focus = App.GetKeyboardFocusedWidget();
            if (Focus) UE_LOG(LogTemp, Display, TEXT("CityExplorer focus key=%s widget=%s origin=%s size=%s"), *Event.GetKey().ToString(), *Focus->GetTypeAsString(), *Focus->GetCachedGeometry().GetAbsolutePosition().ToString(), *Focus->GetCachedGeometry().GetLocalSize().ToString());
        }
        return false;
    }
    virtual bool HandleMouseButtonDownEvent(FSlateApplication& App, const FPointerEvent& Event) override
    {
        for (auto Window : App.GetInteractiveTopLevelWindows()) UE_LOG(LogTemp, Display, TEXT("CityExplorer window origin=%s size=%s dpi=%.2f"), *Window->GetPositionInScreen().ToString(), *Window->GetSizeInScreen().ToString(), Window->GetDPIScaleFactor());
        const auto Path = App.LocateWindowUnderMouse(Event.GetScreenSpacePosition(), App.GetInteractiveTopLevelWindows());
        FString Types; for (int32 I = 0; I < Path.Widgets.Num(); ++I) Types += Path.Widgets[I].Widget->GetTypeAsString() + TEXT("/");
        UE_LOG(LogTemp, Display, TEXT("CityExplorer Slate mouse down position=%s path=%s"), *Event.GetScreenSpacePosition().ToString(), *Types); return false;
    }
};
}
AExplorerGameMode::AExplorerGameMode()
{
    DefaultPawnClass = AExplorerVehicle::StaticClass(); PlayerControllerClass = AExplorerPlayerController::StaticClass();
}
void AExplorerGameMode::InitGame(const FString& MapName, const FString& Options, FString& Error)
{
    Super::InitGame(MapName, Options, Error);
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (!Map->LoadCity()) { Error = Map->GetLastError(); UE_LOG(LogTemp, Error, TEXT("City Explorer: %s"), *Error); }
}
void AExplorerGameMode::StartPlay()
{
    Super::StartPlay();
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (auto* PC = GetWorld()->GetFirstPlayerController()) if (auto* Car = Cast<AExplorerVehicle>(PC->GetPawn()))
    {
        Car->Recover(Map->GetStart()); GetWorld()->GetSubsystem<UExplorerWorldSubsystem>()->StreamAt(Car->GetActorLocation(), true);
        PC->SetPause(true);
#if WITH_DEV_AUTOMATION_TESTS
        if (FParse::Param(FCommandLine::Get(), TEXT("CityExplorerPhysicsProbe"))) GetWorld()->SpawnActor<AExplorerPhysicsProbe>();
#endif
    }
}
void AExplorerPlayerController::BeginPlay()
{
    Super::BeginPlay(); if (!IsLocalController()) return;
    if (!UE_BUILD_SHIPPING) { InputTrace = MakeShared<FExplorerInputTrace>(); FSlateApplication::Get().RegisterInputPreProcessor(InputTrace); }
    AppWidget = CreateWidget<UExplorerAppWidget>(this, AppWidgetClass ? AppWidgetClass.Get() : UExplorerAppWidget::StaticClass());
    AppWidget->AddToViewport();
    GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->OnScreenChanged.AddDynamic(this, &AExplorerPlayerController::ConfigureScreenInput); ShowHome();
    GEngine->SetMaxFPS(GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->Preferences->FrameCap);
    GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->ApplyAudioPreference();
    FCoreDelegates::ApplicationWillDeactivateDelegate.AddUObject(this, &AExplorerPlayerController::PauseOnFocusLoss);
    GetWorldTimerManager().SetTimer(SaveTimer, this, &AExplorerPlayerController::Persist, 3, true);
}
void AExplorerPlayerController::SetupInputComponent()
{
    Super::SetupInputComponent();
    InputComponent->BindKey(EKeys::Escape, IE_Pressed, this, &AExplorerPlayerController::TogglePause).bExecuteWhenPaused = true;
    InputComponent->BindKey(EKeys::P, IE_Pressed, this, &AExplorerPlayerController::TogglePause).bExecuteWhenPaused = true;
    InputComponent->BindKey(EKeys::R, IE_Pressed, this, &AExplorerPlayerController::RecoverVehicle);
    InputComponent->BindKey(EKeys::C, IE_Pressed, this, &AExplorerPlayerController::ResetVehicleCamera);
}
void AExplorerPlayerController::ShowHome()
{
    if (auto* Car = Cast<AExplorerVehicle>(GetPawn())) { Car->DrivePhysics->ClearInput(); SetPause(true); }
    GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->SetScreen(EExplorerScreen::Home);
    ConfigureScreenInput(EExplorerScreen::Home);
}
bool AExplorerPlayerController::BeginExplore(FVector2D Point)
{
    auto* Car = Cast<AExplorerVehicle>(GetPawn()); if (!Car || !Car->Recover(Point)) return false;
    GetWorld()->GetSubsystem<UExplorerWorldSubsystem>()->StreamAt(Car->GetActorLocation(), true);
    SetPause(false);
    GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->SetScreen(EExplorerScreen::Exploring);
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI world started at selected safe road")); Persist(); return true;
}
void AExplorerPlayerController::TogglePause()
{
    auto* Session = GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>(); auto* Car = Cast<AExplorerVehicle>(GetPawn()); if (!Car) return;
    if (Session->Screen == EExplorerScreen::Exploring)
    {
        Car->DrivePhysics->ClearInput(); SetPause(true); Persist();
        Session->SetScreen(EExplorerScreen::Paused);
    }
    else if (Session->Screen == EExplorerScreen::Paused || Session->Screen == EExplorerScreen::Settings)
    {
        SetPause(false); Session->SetScreen(EExplorerScreen::Exploring);
    }
}
void AExplorerPlayerController::Persist()
{
    if (auto* Car = Cast<AExplorerVehicle>(GetPawn())) GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->RecordSafePosition(Car->GetActorLocation(), Car->GetActorRotation());
}
void AExplorerPlayerController::RecoverVehicle()
{
    auto* S = GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>(); auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    const FVector P = S->Preferences->SafePosition;
    BeginExplore(S->Preferences->bHasJourney ? FVector2D(P.X / 100, P.Y / 100) : Map->GetStart());
}
void AExplorerPlayerController::ResetVehicleCamera() { if (auto* Car = Cast<AExplorerVehicle>(GetPawn())) Car->ResetCamera(); }
void AExplorerPlayerController::EndPlay(EEndPlayReason::Type Reason)
{
    if (InputTrace) { FSlateApplication::Get().UnregisterInputPreProcessor(InputTrace); InputTrace.Reset(); }
    FCoreDelegates::ApplicationWillDeactivateDelegate.RemoveAll(this);
    GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->OnScreenChanged.RemoveAll(this);
    Persist(); GetWorldTimerManager().ClearTimer(SaveTimer); Super::EndPlay(Reason);
}

void AExplorerPlayerController::PauseOnFocusLoss()
{
    if (GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->Screen == EExplorerScreen::Exploring) TogglePause();
}

void AExplorerPlayerController::ConfigureScreenInput(EExplorerScreen Screen)
{
    if (!AppWidget || !IsLocalController()) return;
    bShowMouseCursor = true; bEnableClickEvents = true; bEnableMouseOverEvents = true;
    const bool Driving = Screen == EExplorerScreen::Exploring;
    SetPause(!Driving);
    if (Driving)
    {
        FInputModeGameAndUI Mode; Mode.SetHideCursorDuringCapture(false); Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock); SetInputMode(Mode);
        FSlateApplication::Get().SetAllUserFocusToGameViewport();
    }
    else
    {
        if (auto* Car = Cast<AExplorerVehicle>(GetPawn())) Car->DrivePhysics->ClearInput();
        FInputModeUIOnly Mode; Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
        UWidget* Target = AppWidget->GetFocusTarget();
        if (Target) Mode.SetWidgetToFocus(Target->TakeWidget());
        SetInputMode(Mode); if (Target) Target->SetUserFocus(this);
    }
    if (auto* Viewport = GetWorld()->GetGameViewport()) { Viewport->SetMouseCaptureMode(EMouseCaptureMode::NoCapture); Viewport->SetMouseLockMode(EMouseLockMode::DoNotLock); }
    UE_LOG(LogTemp, Display, TEXT("CityExplorer input mode=%s screen=%d cursor=1 capture=none"), Driving ? TEXT("GameAndUI") : TEXT("UIOnly"), int32(Screen));
}

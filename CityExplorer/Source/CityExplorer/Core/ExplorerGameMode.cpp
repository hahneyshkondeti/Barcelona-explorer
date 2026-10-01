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
    AppWidget = CreateWidget<UExplorerAppWidget>(this, AppWidgetClass ? AppWidgetClass.Get() : UExplorerAppWidget::StaticClass());
    AppWidget->AddToViewport(); ShowHome();
    GEngine->SetMaxFPS(GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->Preferences->FrameCap);
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
    bShowMouseCursor = true; SetInputMode(FInputModeUIOnly());
}
bool AExplorerPlayerController::BeginExplore(FVector2D Point)
{
    auto* Car = Cast<AExplorerVehicle>(GetPawn()); if (!Car || !Car->Recover(Point)) return false;
    GetWorld()->GetSubsystem<UExplorerWorldSubsystem>()->StreamAt(Car->GetActorLocation(), true);
    SetPause(false);
    GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->SetScreen(EExplorerScreen::Exploring);
    bShowMouseCursor = true; FInputModeGameAndUI Mode; Mode.SetHideCursorDuringCapture(false); SetInputMode(Mode); Persist(); return true;
}
void AExplorerPlayerController::TogglePause()
{
    auto* Session = GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>(); auto* Car = Cast<AExplorerVehicle>(GetPawn()); if (!Car) return;
    if (Session->Screen == EExplorerScreen::Exploring)
    {
        Car->DrivePhysics->ClearInput(); SetPause(true); Persist();
        Session->SetScreen(EExplorerScreen::Paused); bShowMouseCursor = true; SetInputMode(FInputModeGameAndUI());
    }
    else if (Session->Screen == EExplorerScreen::Paused || Session->Screen == EExplorerScreen::Settings)
    {
        SetPause(false); Session->SetScreen(EExplorerScreen::Exploring); bShowMouseCursor = true; FInputModeGameAndUI Mode; Mode.SetHideCursorDuringCapture(false); SetInputMode(Mode);
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
    FCoreDelegates::ApplicationWillDeactivateDelegate.RemoveAll(this);
    Persist(); GetWorldTimerManager().ClearTimer(SaveTimer); Super::EndPlay(Reason);
}

void AExplorerPlayerController::PauseOnFocusLoss()
{
    if (GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>()->Screen == EExplorerScreen::Exploring) TogglePause();
}

#include "ExplorerPhysicsProbe.h"
#include "../Vehicles/ExplorerVehicle.h"
#include "../Core/ExplorerGameMode.h"
#include "../Core/ExplorerMapSubsystem.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/World.h"
#include "Engine/GameInstance.h"
#include "HAL/PlatformTime.h"
#include "Misc/CoreDelegates.h"
AExplorerPhysicsProbe::AExplorerPhysicsProbe()
{
    PrimaryActorTick.bCanEverTick = true; PrimaryActorTick.bTickEvenWhenPaused = true;
    PrimaryActorTick.TickGroup = TG_PostPhysics;
}
void AExplorerPhysicsProbe::Fail(const TCHAR* Reason)
{
    UE_LOG(LogTemp, Error, TEXT("CITY_EXPLORER_PHYSICS_FAIL: %s"), Reason);
    FPlatformMisc::RequestExitWithStatus(false, 1);
    SetActorTickEnabled(false);
}
void AExplorerPhysicsProbe::BeginPlay()
{
    Super::BeginPlay(); Controller = Cast<AExplorerPlayerController>(GetWorld()->GetFirstPlayerController());
    Car = Controller ? Cast<AExplorerVehicle>(Controller->GetPawn()) : nullptr;
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (!Car || !Controller->BeginExplore(Map->GetStart())) { Fail(TEXT("startup or safe spawn")); return; }
    FCoreDelegates::ApplicationWillDeactivateDelegate.RemoveAll(Controller); // Headless test has no foreground window.
    StageStart = FPlatformTime::Seconds(); Car->DrivePhysics->SetHandbrakeInput(true);
}
void AExplorerPhysicsProbe::Tick(float Delta)
{
    Super::Tick(Delta); if (!Car) return;
    const double Elapsed = FPlatformTime::Seconds() - StageStart;
    if (Car->GetActorLocation().ContainsNaN()) { Fail(TEXT("non-finite body transform")); return; }
    if (Stage == 0 && Elapsed > 2.5)
    {
        int32 Contacts = 0; for (int32 I = 0; I < Car->DrivePhysics->GetNumWheels(); ++I) Contacts += Car->DrivePhysics->GetWheelState(I).bInContact;
        UE_LOG(LogTemp, Display, TEXT("Physics probe: contacts=%d mass=%.1f height=%.1f roll=%.1f"), Contacts, Car->Chassis->GetMass(), Car->GetActorLocation().Z, Car->GetActorRotation().Roll);
        if (Contacts < 3 || FMath::Abs(Car->GetActorRotation().Roll) > 15) { Fail(TEXT("suspension contact or settled stability")); return; }
        Start = Car->GetActorLocation(); Car->DrivePhysics->SetHandbrakeInput(false); Car->DrivePhysics->SetBrakeInput(0); Car->DrivePhysics->SetThrottleInput(0.65);
        Stage = 1; StageStart = FPlatformTime::Seconds();
    }
    else if (Stage == 1 && Elapsed > 3)
    {
        const double Distance = FVector::Distance(Start, Car->GetActorLocation());
        UE_LOG(LogTemp, Display, TEXT("Physics controls: throttle=%.2f brake=%.2f gear=%d target=%d paused=%d ticking=%d awake=%d"), Car->DrivePhysics->GetThrottleInput(), Car->DrivePhysics->GetBrakeInput(), Car->DrivePhysics->GetCurrentGear(), Car->DrivePhysics->GetTargetGear(), GetWorld()->IsPaused(), Car->DrivePhysics->IsComponentTickEnabled(), Car->Chassis->IsAnyRigidBodyAwake());
        UE_LOG(LogTemp, Display, TEXT("Physics probe: driving speed=%.1f cm/s distance=%.1f cm"), Car->DrivePhysics->GetForwardSpeed(), Distance);
        UE_LOG(LogTemp, Display, TEXT("Physics engine: rpm=%.1f mechanical=%d suspension=%d friction=%d velocity=%s"), Car->DrivePhysics->GetEngineRotationSpeed(), Car->DrivePhysics->bMechanicalSimEnabled, Car->DrivePhysics->bSuspensionEnabled, Car->DrivePhysics->bWheelFrictionEnabled, *Car->Chassis->GetPhysicsLinearVelocity().ToString());
        for (int32 I = 0; I < Car->DrivePhysics->GetNumWheels(); ++I) { const auto& W = Car->DrivePhysics->GetWheelState(I); UE_LOG(LogTemp, Display, TEXT("Wheel%d force=%.1f drive=%.1f brake=%.1f contact=%s"), I, W.SpringForce, W.DriveTorque, W.BrakeTorque, *W.ContactPoint.ToString()); }
        if (Distance < 100 || FMath::Abs(Car->DrivePhysics->GetForwardSpeed()) < 100) { Fail(TEXT("engine drivetrain did not propel chassis")); return; }
        Car->DrivePhysics->SetThrottleInput(0); Car->DrivePhysics->SetBrakeInput(1); Stage = 2; StageStart = FPlatformTime::Seconds();
    }
    else if (Stage == 2 && Elapsed > 0.2 && (FMath::Abs(Car->DrivePhysics->GetForwardSpeed()) < 100 || Elapsed > 2))
    {
        if (FMath::Abs(Car->DrivePhysics->GetForwardSpeed()) > 100) { Fail(TEXT("service braking did not stop chassis")); return; }
        Car->DrivePhysics->ClearInput(); Car->DrivePhysics->SetSteeringInput(0.5); Stage = 3; StageStart = FPlatformTime::Seconds();
    }
    else if (Stage == 3 && Elapsed > 1)
    {
        if (Car->DrivePhysics->Wheels.Num() < 4 || FMath::Abs(Car->DrivePhysics->Wheels[0]->GetSteerAngle()) < 5) { Fail(TEXT("front wheel steering")); return; }
        Controller->TogglePause(); PausePosition = Car->GetActorLocation(); Stage = 4; StageStart = FPlatformTime::Seconds();
    }
    else if (Stage == 4 && Elapsed > 0.5)
    {
        if (FVector::Distance(PausePosition, Car->GetActorLocation()) > 1) { Fail(TEXT("paused physics moved chassis")); return; }
        Controller->RecoverVehicle();
        if (Car->Chassis->GetPhysicsLinearVelocity().Size() > 1) { Fail(TEXT("recovery retained velocity")); return; }
        Controller->ShowHome(); UE_LOG(LogTemp, Display, TEXT("CITY_EXPLORER_PHYSICS_SUCCESS"));
        FPlatformMisc::RequestExitWithStatus(false, 0); SetActorTickEnabled(false);
    }
}

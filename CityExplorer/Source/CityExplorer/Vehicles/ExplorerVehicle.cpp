#include "ExplorerVehicle.h"
#include "../Core/ExplorerMapSubsystem.h"

#include "Components/SkeletalMeshComponent.h"
#include "Engine/SkeletalMesh.h"
#include "Animation/AnimInstance.h"
#include "GameFramework/SpringArmComponent.h"
#include "Camera/CameraComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/GameInstance.h"
#include "Engine/LocalPlayer.h"
#include "GameFramework/PlayerController.h"
#include "Engine/StaticMesh.h"
#include "UObject/ConstructorHelpers.h"
UExplorerFrontWheel::UExplorerFrontWheel()
{
    AxleType = EAxleType::Front; WheelRadius = 39; WheelWidth = 26; WheelMass = 18;
    bAffectedBySteering = true; bAffectedByBrake = true; bAffectedByHandbrake = false;
    MaxSteerAngle = 32; MaxBrakeTorque = 1800;
    FrictionForceMultiplier = 1.2; CorneringStiffness = 1000; WheelLoadRatio = 0.8;
    // UE5.8 converts this property by100 before applying centimetre displacement:350 corresponds to35kN/m.
    SpringRate = 350; SpringPreload = 500; SuspensionMaxRaise = 12; SuspensionMaxDrop = 18;
    SuspensionDampingRatio = 0.65; RollbarScaling = 0.2; SweepType = ESweepType::ComplexSweep;
    bABSEnabled = true; bTractionControlEnabled = true;
}
UExplorerRearWheel::UExplorerRearWheel()
{
    AxleType = EAxleType::Rear; bAffectedBySteering = false; bAffectedByHandbrake = true;
    MaxBrakeTorque = 1400; MaxHandBrakeTorque = 2200;
}
UExplorerVehicleMovement::UExplorerVehicleMovement()
{
    Mass = 1300; bEnableCenterOfMassOverride = true; CenterOfMassOverride = FVector(0, 0, 45);
    bReverseAsBrake = true; bThrottleAsBrake = true;
    EngineSetup.MaxTorque = 260; EngineSetup.MaxRPM = 6500; EngineSetup.EngineIdleRPM = 850;
    auto* Torque = EngineSetup.TorqueCurve.GetRichCurve();
    Torque->AddKey(0, 0.35); Torque->AddKey(1500, 0.7); Torque->AddKey(3500, 1); Torque->AddKey(5500, 0.9); Torque->AddKey(6500, 0.6);
    DifferentialSetup.DifferentialType = EVehicleDifferential::RearWheelDrive;
    TransmissionSetup.FinalRatio = 3.7; TransmissionSetup.ForwardGearRatios = {3.5, 2.1, 1.4, 1.0, 0.8};
    TransmissionSetup.ReverseGearRatios = {3.2}; TransmissionSetup.GearChangeTime = 0.25;
    SteeringSetup.SteeringType = ESteeringType::Ackermann;
    auto* Steering = SteeringSetup.SteeringCurve.GetRichCurve(); Steering->Reset();
    Steering->AddKey(0, 1); Steering->AddKey(30, 0.7); Steering->AddKey(80, 0.35); Steering->AddKey(150, 0.2);
    ThrottleInputRate.RiseRate = 3; ThrottleInputRate.FallRate = 6;
    BrakeInputRate.RiseRate = 6; BrakeInputRate.FallRate = 10;
    SteeringInputRate.RiseRate = 2.5; SteeringInputRate.FallRate = 4;
    WheelSetups.SetNum(4);
    for (int32 I = 0; I < 4; ++I)
    {
        WheelSetups[I].WheelClass = I < 2 ? UExplorerFrontWheel::StaticClass() : UExplorerRearWheel::StaticClass();
        const FName Names[] = {TEXT("Wheel_FL"), TEXT("Wheel_FR"), TEXT("Wheel_RL"), TEXT("Wheel_RR")};
        WheelSetups[I].BoneName = Names[I];
        WheelSetups[I].AdditionalOffset = FVector::ZeroVector;
    }
}
AExplorerVehicle::AExplorerVehicle(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer.SetDefaultSubobjectClass<UExplorerVehicleMovement>(VehicleMovementComponentName))
{
    Chassis = GetMesh(); DrivePhysics = CastChecked<UExplorerVehicleMovement>(GetVehicleMovementComponent());
    static ConstructorHelpers::FObjectFinder<USkeletalMesh> CarMesh(TEXT("/Game/CityExplorer/Vehicles/TouringCar/TouringCarRigged/SkeletalMeshes/SK_TouringCar.SK_TouringCar"));
    if (CarMesh.Succeeded()) Chassis->SetSkeletalMesh(CarMesh.Object);
    static ConstructorHelpers::FClassFinder<UAnimInstance> CarAnimation(TEXT("/Game/CityExplorer/Vehicles/ABP_TouringCar"));
    if (CarAnimation.Succeeded()) Chassis->SetAnimInstanceClass(CarAnimation.Class);
    Chassis->SetSimulatePhysics(true); Chassis->SetEnableGravity(true); Chassis->SetUseCCD(true);
    CameraArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("ChaseArm")); CameraArm->SetupAttachment(Chassis);
    CameraArm->TargetArmLength = 850; CameraArm->SetRelativeLocation(FVector(0, 0, 170)); CameraArm->SetRelativeRotation(FRotator(-15, 0, 0));
    CameraArm->bEnableCameraLag = true; CameraArm->CameraLagSpeed = 6; CameraArm->ProbeSize = 30;
    Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("ChaseCamera")); Camera->SetupAttachment(CameraArm); Camera->FieldOfView = 60;
}
UPawnMovementComponent* AExplorerVehicle::GetMovementComponent() const { return DrivePhysics; }
void AExplorerVehicle::PawnClientRestart()
{
    Super::PawnClientRestart();
    if (auto* PC = Cast<APlayerController>(GetController()))
        if (auto* Local = PC->GetLocalPlayer())
            if (auto* Input = Local->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>())
                if (DriveContext) Input->AddMappingContext(DriveContext, 0);
}
void AExplorerVehicle::SetupPlayerInputComponent(UInputComponent* Input)
{
    Super::SetupPlayerInputComponent(Input);
    if (auto* Enhanced = Cast<UEnhancedInputComponent>(Input))
    {
        if (GasAction) { Enhanced->BindAction(GasAction, ETriggerEvent::Triggered, this, &AExplorerVehicle::SetGas); Enhanced->BindAction(GasAction, ETriggerEvent::Completed, this, &AExplorerVehicle::SetGas); Enhanced->BindAction(GasAction, ETriggerEvent::Canceled, this, &AExplorerVehicle::SetGas); }
        if (BrakeAction) { Enhanced->BindAction(BrakeAction, ETriggerEvent::Triggered, this, &AExplorerVehicle::SetBrake); Enhanced->BindAction(BrakeAction, ETriggerEvent::Completed, this, &AExplorerVehicle::SetBrake); Enhanced->BindAction(BrakeAction, ETriggerEvent::Canceled, this, &AExplorerVehicle::SetBrake); }
        if (SteerAction) { Enhanced->BindAction(SteerAction, ETriggerEvent::Triggered, this, &AExplorerVehicle::SetSteer); Enhanced->BindAction(SteerAction, ETriggerEvent::Completed, this, &AExplorerVehicle::SetSteer); Enhanced->BindAction(SteerAction, ETriggerEvent::Canceled, this, &AExplorerVehicle::SetSteer); }
    }
}
void AExplorerVehicle::SetGas(const FInputActionValue& Value) { DrivePhysics->SetThrottleInput(Value.Get<float>()); }
void AExplorerVehicle::SetBrake(const FInputActionValue& Value) { DrivePhysics->SetBrakeInput(Value.Get<float>()); }
void AExplorerVehicle::SetSteer(const FInputActionValue& Value) { DrivePhysics->SetSteeringInput(Value.Get<float>()); }
bool AExplorerVehicle::Recover(FVector2D Point)
{
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>(); FVector Position; FRotator Rotation;
    if (!ensure(DrivePhysics && Chassis) || !Map || !Map->SafeSpawn(Point, Position, Rotation)) return false;
    DrivePhysics->ClearInput(); DrivePhysics->ResetVehicle();
    Chassis->SetPhysicsLinearVelocity(FVector::ZeroVector); Chassis->SetPhysicsAngularVelocityInDegrees(FVector::ZeroVector);
    Position.Z -= 35; // Rig root is the car ground origin, not the old collider centre.
    SetActorLocationAndRotation(Position, Rotation, false, nullptr, ETeleportType::TeleportPhysics); ResetCamera(); return true;
}
void AExplorerVehicle::ResetCamera()
{
    CameraArm->bEnableCameraLag = false;
    CameraArm->TickComponent(0, LEVELTICK_All, nullptr);
    CameraArm->bEnableCameraLag = true;
}

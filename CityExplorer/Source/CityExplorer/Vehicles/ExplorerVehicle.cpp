#include "ExplorerVehicle.h"
#include "../Core/ExplorerMapSubsystem.h"
#include "Components/BoxComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "Camera/CameraComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/GameInstance.h"
#include "Engine/LocalPlayer.h"
#include "GameFramework/PlayerController.h"
#include "Engine/StaticMesh.h"
#include "UObject/ConstructorHelpers.h"
UExplorerVehicleMovement::UExplorerVehicleMovement() { PrimaryComponentTick.bCanEverTick = true; }
void UExplorerVehicleMovement::TickComponent(float Delta, ELevelTick Type, FActorComponentTickFunction* Function)
{
    Super::TickComponent(Delta, Type, Function);
    if (!PawnOwner || !UpdatedComponent || ShouldSkipUpdate(Delta)) return;
    auto* Map = PawnOwner->GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (!Map || !Map->IsReady()) return;
    double Remaining = FMath::Min(double(Delta), 0.25);
    while (Remaining > 0.000001)
    {
        const double Step = FMath::Min(Remaining, 1.0 / 120); Remaining -= Step;
        Handling.Step(Step, Gas, Brake, Steer);
        auto Rotation = UpdatedComponent->GetComponentRotation(); Rotation.Yaw += FMath::RadiansToDegrees(Handling.YawRate * Step);
        const FVector Forward = Rotation.Vector(); const auto Current = UpdatedComponent->GetComponentLocation();
        FVector Next = Current + Forward * Handling.Speed * Step * 100;
        FVector Safe; FRotator Heading;
        if (!Map->SafeSpawn(FVector2D(Next.X / 100, Next.Y / 100), Safe, Heading)) { Handling.Reset(); return; }
        Next.Z = (Map->GetTerrain().Height(Next.X / 100, Next.Y / 100) + 0.75) * 100;
        FHitResult Hit;
        SafeMoveUpdatedComponent(Next - Current, Rotation.Quaternion(), true, Hit);
        if (Hit.IsValidBlockingHit())
        {
            const FVector Actual = UpdatedComponent->GetComponentLocation() - Current;
            Handling.Speed = FMath::Clamp(FVector::DotProduct(Actual, Forward) / (Step * 100), FMath::Min(Handling.Speed, 0.0), FMath::Max(Handling.Speed, 0.0));
            Handling.YawRate *= FMath::Exp(-8 * Step);
        }
    }
    Velocity = UpdatedComponent->GetForwardVector() * Handling.Speed * 100;
    UpdateComponentVelocity();
}
AExplorerVehicle::AExplorerVehicle()
{
    Hull = CreateDefaultSubobject<UBoxComponent>(TEXT("Hull")); SetRootComponent(Hull);
    Hull->SetBoxExtent(FVector(185, 92.5, 55)); Hull->SetCollisionProfileName(TEXT("Pawn"));
    Movement = CreateDefaultSubobject<UExplorerVehicleMovement>(TEXT("Movement")); Movement->SetUpdatedComponent(Hull);
    CameraArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("ChaseArm")); CameraArm->SetupAttachment(Hull);
    CameraArm->TargetArmLength = 850; CameraArm->SetRelativeLocation(FVector(0, 0, 170)); CameraArm->SetRelativeRotation(FRotator(-15, 0, 0));
    CameraArm->bEnableCameraLag = true; CameraArm->CameraLagSpeed = 6; CameraArm->ProbeSize = 30;
    Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("ChaseCamera")); Camera->SetupAttachment(CameraArm); Camera->FieldOfView = 60;
    auto* Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body")); Body->SetupAttachment(Hull); Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
    if (Cube.Succeeded()) Body->SetStaticMesh(Cube.Object);
    Body->SetRelativeScale3D(FVector(3.7, 1.85, 1.1));
    // Configurable Blueprint mesh replaces this collision-sized development visual.
}
UPawnMovementComponent* AExplorerVehicle::GetMovementComponent() const { return Movement; }
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
void AExplorerVehicle::SetGas(const FInputActionValue& Value) { Movement->Gas = Value.Get<float>(); }
void AExplorerVehicle::SetBrake(const FInputActionValue& Value) { Movement->Brake = Value.Get<float>(); }
void AExplorerVehicle::SetSteer(const FInputActionValue& Value) { Movement->Steer = Value.Get<float>(); }
bool AExplorerVehicle::Recover(FVector2D Point)
{
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>(); FVector Position; FRotator Rotation;
    if (!Map || !Map->SafeSpawn(Point, Position, Rotation)) return false;
    Movement->ClearInput(); Movement->Handling.Reset(); Movement->Velocity = FVector::ZeroVector;
    SetActorLocationAndRotation(Position, Rotation, false, nullptr, ETeleportType::TeleportPhysics); ResetCamera(); return true;
}
void AExplorerVehicle::ResetCamera()
{
    CameraArm->bEnableCameraLag = false;
    CameraArm->TickComponent(0, LEVELTICK_All, nullptr);
    CameraArm->bEnableCameraLag = true;
}

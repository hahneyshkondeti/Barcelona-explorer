#pragma once
#include "CoreMinimal.h"
#include "WheeledVehiclePawn.h"
#include "ChaosWheeledVehicleMovementComponent.h"
#include "ChaosVehicleWheel.h"
#include "../Core/ExplorerHandling.h"
#include "InputActionValue.h"
#include "ExplorerVehicle.generated.h"
class USkeletalMeshComponent;
class USpringArmComponent;
class UCameraComponent;
class UInputAction;
class UInputMappingContext;
UCLASS()
class CITYEXPLORER_API UExplorerFrontWheel : public UChaosVehicleWheel
{
    GENERATED_BODY()
public:
    UExplorerFrontWheel();
};
UCLASS()
class CITYEXPLORER_API UExplorerRearWheel : public UExplorerFrontWheel
{
    GENERATED_BODY()
public:
    UExplorerRearWheel();
};
UCLASS(ClassGroup=Movement, meta=(BlueprintSpawnableComponent))
class CITYEXPLORER_API UExplorerVehicleMovement : public UChaosWheeledVehicleMovementComponent
{
    GENERATED_BODY()
public:
    UExplorerVehicleMovement();
    void ClearInput() { SetThrottleInput(0); SetBrakeInput(0); SetSteeringInput(0); SetHandbrakeInput(false); }

};
UCLASS(Blueprintable)
class CITYEXPLORER_API AExplorerVehicle : public AWheeledVehiclePawn
{
    GENERATED_BODY()
public:
    AExplorerVehicle(const FObjectInitializer& ObjectInitializer);
    virtual UPawnMovementComponent* GetMovementComponent() const override;
    virtual void SetupPlayerInputComponent(UInputComponent* Input) override;
    virtual void PawnClientRestart() override;
    UFUNCTION(BlueprintCallable) bool Recover(FVector2D Point);
    UFUNCTION(BlueprintCallable) void ResetCamera();
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UExplorerVehicleMovement> DrivePhysics;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<USkeletalMeshComponent> Chassis;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<USpringArmComponent> CameraArm;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UCameraComponent> Camera;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly) TObjectPtr<UInputMappingContext> DriveContext;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly) TObjectPtr<UInputAction> GasAction;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly) TObjectPtr<UInputAction> BrakeAction;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly) TObjectPtr<UInputAction> SteerAction;
private:
    void SetGas(const FInputActionValue& Value);
    void SetBrake(const FInputActionValue& Value);
    void SetSteer(const FInputActionValue& Value);
};

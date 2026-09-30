#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PawnMovementComponent.h"
#include "../Core/ExplorerHandling.h"
#include "InputActionValue.h"
#include "ExplorerVehicle.generated.h"
class UBoxComponent;
class USpringArmComponent;
class UCameraComponent;
class UInputAction;
class UInputMappingContext;
UCLASS(ClassGroup=Movement, meta=(BlueprintSpawnableComponent))
class CITYEXPLORER_API UExplorerVehicleMovement : public UPawnMovementComponent
{
    GENERATED_BODY()
public:
    UExplorerVehicleMovement();
    virtual void TickComponent(float Delta, ELevelTick Type, FActorComponentTickFunction* Function) override;
    FExplorerHandling Handling;
    float Gas = 0, Brake = 0, Steer = 0;
    void ClearInput() { Gas = Brake = Steer = 0; }
};
UCLASS(Blueprintable)
class CITYEXPLORER_API AExplorerVehicle : public APawn
{
    GENERATED_BODY()
public:
    AExplorerVehicle();
    virtual UPawnMovementComponent* GetMovementComponent() const override;
    virtual void SetupPlayerInputComponent(UInputComponent* Input) override;
    virtual void PawnClientRestart() override;
    UFUNCTION(BlueprintCallable) bool Recover(FVector2D Point);
    UFUNCTION(BlueprintCallable) void ResetCamera();
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UExplorerVehicleMovement> Movement;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UBoxComponent> Hull;
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

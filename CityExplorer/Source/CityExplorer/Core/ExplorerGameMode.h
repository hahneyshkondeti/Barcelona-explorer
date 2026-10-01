#pragma once
#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/PlayerController.h"
#include "ExplorerSessionSubsystem.h"
#include "ExplorerGameMode.generated.h"
class UExplorerAppWidget;
UCLASS()
class CITYEXPLORER_API AExplorerPlayerController : public APlayerController
{
    GENERATED_BODY()
public:
    virtual void BeginPlay() override;
    virtual void SetupInputComponent() override;
    virtual void EndPlay(EEndPlayReason::Type Reason) override;
    UFUNCTION(BlueprintCallable) void TogglePause();
    UFUNCTION(BlueprintCallable) void ShowHome();
    UFUNCTION(BlueprintCallable) bool BeginExplore(FVector2D Point);
    UFUNCTION(BlueprintCallable) void RecoverVehicle();
    UFUNCTION(BlueprintCallable) void ResetVehicleCamera();
    UPROPERTY(EditDefaultsOnly) TSubclassOf<UExplorerAppWidget> AppWidgetClass;
    UPROPERTY() TObjectPtr<UExplorerAppWidget> AppWidget;
private:
    FTimerHandle SaveTimer;
    TSharedPtr<class IInputProcessor> InputTrace;
    void Persist();
    void PauseOnFocusLoss();
    UFUNCTION() void ConfigureScreenInput(EExplorerScreen Screen);
};
UCLASS()
class CITYEXPLORER_API AExplorerGameMode : public AGameModeBase
{
    GENERATED_BODY()
public:
    AExplorerGameMode();
    virtual void InitGame(const FString& MapName, const FString& Options, FString& Error) override;
    virtual void StartPlay() override;
};

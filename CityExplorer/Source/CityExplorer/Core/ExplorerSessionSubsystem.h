#pragma once
#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "ExplorerSessionSubsystem.generated.h"

UENUM(BlueprintType)
enum class EExplorerScreen : uint8 { Home, City, Location, Vehicle, Exploring, Paused, Settings };
UCLASS()
class CITYEXPLORER_API UExplorerSaveGame : public USaveGame
{
    GENERATED_BODY()
public:
    UPROPERTY(SaveGame) int32 Version = 1;
    UPROPERTY(SaveGame) FVector SafePosition = FVector::ZeroVector;
    UPROPERTY(SaveGame) FRotator Heading = FRotator::ZeroRotator;
    UPROPERTY(SaveGame) bool bHasJourney = false;
    UPROPERTY(SaveGame) bool bMuted = false;
    UPROPERTY(SaveGame) bool bNorthLocked = false;
    UPROPERTY(SaveGame) int32 FrameCap = 30;
    UPROPERTY(SaveGame) FString Theme = TEXT("dark");
    UPROPERTY(SaveGame) FString CityId = TEXT("barcelona");
    UPROPERTY(SaveGame) FString VehicleId = TEXT("touring_car");
    UPROPERTY(SaveGame) TArray<FString> Discoveries;
};
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FExplorerScreenChanged, EExplorerScreen, Screen);
UCLASS()
class CITYEXPLORER_API UExplorerSessionSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()
public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    UPROPERTY(BlueprintReadOnly) EExplorerScreen Screen = EExplorerScreen::Home;
    UPROPERTY(BlueprintReadOnly) TObjectPtr<UExplorerSaveGame> Preferences;
    UPROPERTY(BlueprintAssignable) FExplorerScreenChanged OnScreenChanged;
    UFUNCTION(BlueprintCallable) void SetScreen(EExplorerScreen Value);
    UFUNCTION(BlueprintCallable) bool SavePreferences();
    UFUNCTION(BlueprintCallable) bool RecordSafePosition(FVector Position, FRotator Heading);
};

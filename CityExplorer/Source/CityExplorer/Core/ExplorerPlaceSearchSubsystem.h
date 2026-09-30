#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "ExplorerMapSubsystem.h"
#include "Interfaces/IHttpRequest.h"
#include "ExplorerPlaceSearchSubsystem.generated.h"
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FExplorerSearchResults, const TArray<FExplorerPlace>&, Results);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FExplorerPlaceResolved, FExplorerPlace, Place);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FExplorerSearchError, FString, Message);
UCLASS()
class CITYEXPLORER_API UExplorerPlaceSearchSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()
public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;
    UFUNCTION(BlueprintCallable) void Search(const FString& Query);
    UFUNCTION(BlueprintCallable) void Resolve(FExplorerPlace Place);
    UFUNCTION(BlueprintPure) bool HasGoogleKey() const { return !ApiKey.IsEmpty(); }
    UPROPERTY(BlueprintAssignable) FExplorerSearchResults OnResults;
    UPROPERTY(BlueprintAssignable) FExplorerPlaceResolved OnResolved;
    UPROPERTY(BlueprintAssignable) FExplorerSearchError OnError;
private:
    FString ApiKey;
    int32 Generation = 0;
    TSharedPtr<IHttpRequest, ESPMode::ThreadSafe> Request;
    void Cancel();
};

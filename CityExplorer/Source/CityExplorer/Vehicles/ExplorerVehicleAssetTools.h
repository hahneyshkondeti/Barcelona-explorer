#pragma once
#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "ExplorerVehicleAssetTools.generated.h"
class UPhysicsAsset;
UCLASS()
class CITYEXPLORER_API UExplorerVehicleAssetTools : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable, Category="CityExplorer|Editor")
    static bool ConfigureChassis(UPhysicsAsset* Asset);
    UFUNCTION(BlueprintCallable, Category="CityExplorer|Editor")
    static class UBlueprint* CreateWheelAnimation(class USkeleton* Skeleton);
};

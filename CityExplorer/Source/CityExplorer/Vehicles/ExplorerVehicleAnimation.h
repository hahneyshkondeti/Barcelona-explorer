#pragma once
#include "CoreMinimal.h"
#include "VehicleAnimationInstance.h"
#include "ExplorerVehicleAnimation.generated.h"
// Small native animation graph: reference pose → standard Chaos wheel controller.
UCLASS(Transient)
class CITYEXPLORER_API UExplorerVehicleAnimation : public UVehicleAnimationInstance
{
    GENERATED_BODY()
protected:
    virtual FAnimInstanceProxy* CreateAnimInstanceProxy() override;
    virtual void DestroyAnimInstanceProxy(FAnimInstanceProxy* Proxy) override;
};
